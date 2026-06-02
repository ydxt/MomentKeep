import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moment_keep/core/services/storage_service.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/presentation/components/app_search_bar.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/components/user_points_provider.dart';
import 'package:moment_keep/presentation/pages/my_orders_page.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:moment_keep/presentation/pages/merchant_product_management_page.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';
import 'package:moment_keep/presentation/pages/product_review_page.dart';
import 'package:moment_keep/presentation/pages/shopping_cart_page.dart';
import 'package:moment_keep/presentation/pages/bills_page.dart';
import 'package:moment_keep/presentation/pages/coupons_detail_page.dart';
import 'package:moment_keep/presentation/pages/shopping_card_page.dart';
import 'package:moment_keep/presentation/pages/distribution_center_page.dart';
import 'package:moment_keep/presentation/pages/logistics_page.dart';
import 'package:moment_keep/presentation/pages/merchant_management_page.dart';
import 'package:moment_keep/presentation/pages/stock_records_page.dart';
import 'package:moment_keep/presentation/pages/merchant_finance_page.dart';
import 'package:moment_keep/presentation/pages/client_payment_records_page.dart';
import 'package:moment_keep/presentation/pages/merchant_payment_records_page.dart';
import 'package:moment_keep/presentation/pages/favorite_products_page.dart';
import 'package:moment_keep/presentation/pages/browsing_history_page.dart';
import 'package:moment_keep/presentation/pages/product_review_management_page.dart';
import 'package:moment_keep/presentation/pages/coupon_management_page.dart';
import 'package:moment_keep/presentation/pages/red_packet_management_page.dart';
import 'package:moment_keep/presentation/pages/global_search_page.dart';
import 'package:moment_keep/presentation/pages/settings_page.dart';
import 'package:moment_keep/presentation/pages/card_secret_page.dart';
import 'package:moment_keep/presentation/pages/member_level_page.dart';
import 'package:moment_keep/presentation/pages/merchant_dashboard_page.dart';
import 'package:moment_keep/presentation/pages/admin_dashboard_page.dart';
import 'package:moment_keep/presentation/pages/user_info_page.dart';
import 'package:moment_keep/presentation/pages/points_exchange_page.dart';
import 'package:moment_keep/presentation/pages/limited_deals_page.dart';
import 'package:moment_keep/presentation/pages/virtual_products_page.dart';
import 'package:moment_keep/presentation/pages/more_features_page.dart';
import 'package:moment_keep/presentation/pages/ranking_page.dart';

enum StoreRole { client, merchant, admin }

class StarExchangePage extends ConsumerStatefulWidget {
  /// 构造函数
  const StarExchangePage({super.key});

  @override
  ConsumerState<StarExchangePage> createState() => _StarExchangePageState();
}

class _StarExchangePageState extends ConsumerState<StarExchangePage> {
  /// 客户端功能导航区是否折叠
  bool _isFeatureNavCollapsed = false;

  /// 客户端功能列表
  List<Map<String, dynamic>> get _features {
    return [
      {'icon': Icons.receipt_long, 'label': '我的订单', 'page': const MyOrdersPage(), 'badgeCount': 0},
      {'icon': Icons.account_balance_wallet, 'label': '账单', 'page': const BillsPage(), 'badgeCount': 0},
      {'icon': Icons.payment, 'label': '支付记录', 'page': const ClientPaymentRecordsPage(), 'badgeCount': 0},
      {'icon': Icons.favorite, 'label': '我的收藏', 'page': const FavoriteProductsPage(), 'badgeCount': 0},
      {'icon': Icons.history, 'label': '浏览足迹', 'page': const BrowsingHistoryPage(), 'badgeCount': 0},
      {'icon': Icons.local_offer, 'label': '优惠券', 'page': const CouponsDetailPage(), 'badgeCount': 0},
      {'icon': Icons.key, 'label': '卡密中心', 'page': const CardSecretPage(), 'badgeCount': 0},
      {'icon': Icons.workspace_premium, 'label': '会员权益', 'page': const MemberLevelPage(), 'badgeCount': 0},
      {'icon': Icons.share, 'label': '分销中心', 'page': const DistributionCenterPage(), 'badgeCount': 0},
    ];
  }

  /// 当前商店角色
  StoreRole _currentRole = StoreRole.client;

  /// 平台检测
  bool get _isDesktop => kIsWeb ? false : (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);
  bool get _isWideScreen => MediaQuery.of(context).size.width >= 600;
  bool get _useDesktopLayout => _isDesktop || _isWideScreen;

  /// 桌面端导航选中索引
  int _selectedDesktopPageIndex = 0;

  /// 当前选中的筛选标签索引
  int _selectedFilterIndex = 0;

  List<Map<String, dynamic>> _activities = [
    {'title': '限时优惠', 'description': '精选商品8折起', 'icon': Icons.local_offer, 'color': const Color(0xFFff6b6b)},
    {'title': '新品上市', 'description': '本周热门好物', 'icon': Icons.new_releases, 'color': const Color(0xFF4ecdc4)},
    {'title': '积分兑换', 'description': '双倍积分活动', 'icon': Icons.auto_awesome, 'color': const Color(0xFF45b7d1)},
  ];
  int _currentActivityIndex = 0;
  Timer? _carouselTimer;

  /// 数据库服务实例
  final ProductDatabaseService _databaseService = ProductDatabaseService();

  /// 分类列表数据
  List<StarCategory> _categories = [];

  /// 奖励卡片数据
  List<StarProduct> _rewards = [];

  /// 推荐商品数据
  List<StarProduct> _recommendedProducts = [];
  bool _isLoadingRecommendations = false;

  /// 搜索关键词
  String _searchQuery = '';

  /// 是否正在搜索
  bool _isSearching = false;

  bool _isProcessing = false;

  /// 优惠券、红包和购物卡选择
  List<Map<String, dynamic>> _selectedCoupons = [];
  List<Map<String, dynamic>> _selectedRedPackets = [];
  List<Map<String, dynamic>> _selectedShoppingCards = [];

  /// 筛选标签列表（包含全部和所有分类）
  List<String> get _filters {
    return ['全部'] + _categories.map((category) => category.name).toList();
  }

  /// 获取经过分类筛选、状态筛选和搜索筛选后的商品列表
  List<StarProduct> get _filteredRewards {
    var results = _rewards;

    if (_selectedFilterIndex > 0) {
      final categoryId = _categories[_selectedFilterIndex - 1].id;
      results = results.where((p) => p.categoryId == categoryId).toList();
    }

    results = results
        .where((p) =>
            (p.status == 'approved' || p.status == 'active') && p.isActive)
        .toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              (p.description?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    return results;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _initCarouselTimer();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _initCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _currentActivityIndex = (_currentActivityIndex + 1) % _activities.length;
        });
      }
    });
  }

  /// 从数据库加载数据
  Future<void> _loadData() async {
    try {
      ref.read(userPointsProvider.notifier).refresh();

      final categoriesResults = await _databaseService.getAllCategories();
      final categories = categoriesResults
          .map<StarCategory>((map) => StarCategory.fromMap(map))
          .toList();

      // 加载商品数据
      final productsResults = await _databaseService.getAllProducts();
      final products = productsResults
          .map<StarProduct>((map) => StarProduct.fromMap(map))
          .toList();

      debugPrint('加载到的分类数量: ${categories.length}');
      debugPrint('分类列表: ${categories.map((c) => c.name).toList()}');

      setState(() {
        _categories = categories;
        _rewards = products;
      });

      // 异步加载推荐商品
      _loadRecommendations();
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }
  }

  /// 加载推荐商品
  Future<void> _loadRecommendations() async {
    try {
      setState(() {
        _isLoadingRecommendations = true;
      });

      final userId = await DatabaseService().getCurrentUserId() ?? 'default_user';
      final recommendedResults = await _databaseService.getRecommendedProducts(
        userId: userId,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _recommendedProducts = recommendedResults
              .map<StarProduct>((map) => StarProduct.fromMap(map))
              .toList();
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('加载推荐商品失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  /// 处理商品兑换
  Future<void> _handleExchange(StarProduct product) async {
    if (_isProcessing) return;
    await _showPaymentDialog(product);
  }

  /// 显示兑换确认对话框
  Future<bool> _showExchangeConfirmationDialog(
      StarProduct product, int quantity, PaymentMethod paymentMethod) async {
    // 根据支付方式计算总费用
    String confirmationText;
    switch (paymentMethod) {
      case PaymentMethod.points:
        confirmationText =
            '确定要使用 ${product.points * quantity} 积分兑换 $quantity 个 ${product.name} 吗？';
        break;
      case PaymentMethod.cash:
        confirmationText =
            '确定要使用 ¥${product.price * quantity} 现金购买 $quantity 个 ${product.name} 吗？';
        break;
      case PaymentMethod.hybrid:
        final hybridPrice =
            product.hybridPrice > 0 ? product.hybridPrice : product.price ~/ 2;
        final hybridPoints = product.hybridPoints > 0
            ? product.hybridPoints
            : product.points ~/ 2;
        confirmationText =
            '确定要使用 ¥${hybridPrice * quantity} + ${hybridPoints * quantity} 积分兑换 $quantity 个 ${product.name} 吗？';
        break;
      case PaymentMethod.shoppingCard:
        confirmationText = '确定要使用购物卡购买 $quantity 个 ${product.name} 吗？';
        break;
    }

    final theme = ref.watch(currentThemeProvider);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: theme.colorScheme.surfaceVariant,
            title: Text(
              '确认兑换',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  confirmationText,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: ImageLoaderService.getImageProvider(product.image),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: Text(
                  '取消',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('确认兑换'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // 移除不再需要的方法：_startBlinking、_showAddEditRewardDialog、_showDeleteConfirmationDialog、_showManageCategoriesDialog、_showAddEditCategoryDialog、_showDeleteCategoryConfirmationDialog

  int _selectedBottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    if (_useDesktopLayout) {
      // 桌面版：两栏式布局
      return _buildDesktopLayout(theme);
    } else {
      // 手机版：垂直滚动布局
      return _buildMobileLayout(theme);
    }
  }

  /// 桌面版两栏式布局
  Widget _buildDesktopLayout(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 顶部栏（通用）
          _buildTopBar(theme),
          // 主体：左导航 + 右内容
          Expanded(
            child: Row(
              children: [
                _buildLeftSidebar(theme),
                const VerticalDivider(width: 1),
                Expanded(child: _buildDesktopRightContent(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 通用顶部栏（搜索 + 购物车 + 用户中心）
  Widget _buildTopBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlobalSearchPage()),
                );
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '搜索商品名称或描述...',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShoppingCartPage()),
                  );
                },
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: const Text(
                    '0',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 桌面版左侧导航栏
  Widget _buildLeftSidebar(ThemeData theme) {
    return Container(
      width: 240,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // 分类列表
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '商品分类',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.grid_view_outlined, color: _selectedFilterIndex == 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                    title: Text('全部商品', style: TextStyle(color: _selectedFilterIndex == 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minVerticalPadding: 8,
                    dense: true,
                    selected: _selectedFilterIndex == 0,
                    selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedFilterIndex = 0;
                      });
                    },
                  ),
                  ..._categories.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final category = entry.value;
                    return ListTile(
                      leading: Icon(Icons.category_outlined, color: _selectedFilterIndex == index ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                      title: Text(category.name, style: TextStyle(color: _selectedFilterIndex == index ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minVerticalPadding: 8,
                      dense: true,
                      selected: _selectedFilterIndex == index,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = index;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          // 底部角色切换
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '角色切换',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildSidebarRoleButton(StoreRole.client, '客户端', Icons.person, theme),
                _buildSidebarRoleButton(StoreRole.merchant, '商家', Icons.store, theme),
                _buildSidebarRoleButton(StoreRole.admin, '管理员', Icons.admin_panel_settings, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarRoleButton(StoreRole role, String label, IconData icon, ThemeData theme) {
    final isSelected = _currentRole == role;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _currentRole = role),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 桌面版右侧内容区
  Widget _buildDesktopRightContent(ThemeData theme) {
    return _buildRoleContent(theme);
  }

  /// 构建主页内容（提取为独立方法）
  Widget _buildClientContent(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildActivityCarousel()),
        SliverToBoxAdapter(child: _buildClientFeatureNav(theme)),
        SliverToBoxAdapter(child: _buildQuickAccessGrid(theme)),
        SliverToBoxAdapter(child: _buildSectionHeader('精选推荐', theme)),
        _buildProductSliverGrid(theme),
        if (_recommendedProducts.isNotEmpty || _isLoadingRecommendations) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('猜你喜欢', theme)),
          _buildRecommendedProductsGrid(theme),
        ],
      ],
    );
  }

  /// 手机版布局
  Widget _buildMobileLayout(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _buildMobileContent(theme),
      bottomNavigationBar: _currentRole == StoreRole.client
          ? BottomNavigationBar(
              currentIndex: _selectedBottomNavIndex,
              onTap: (index) {
                setState(() {
                  _selectedBottomNavIndex = index;
                });
                _onMobileBottomNavItemTapped(index);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.onSurfaceVariant,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '订单'),
                BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: '购物车'),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '账单'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
              ],
            )
          : null,
    );
  }

  /// 手机版内容区（优化顺序）
  Widget _buildMobileContent(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildTopBar(theme)),
        SliverToBoxAdapter(child: _buildActivityCarousel()),
        SliverToBoxAdapter(child: _buildClientFeatureNav(theme)),
        SliverToBoxAdapter(child: _buildRoleSwitcher(theme)),
        SliverToBoxAdapter(child: _buildQuickAccessGrid(theme)),
        SliverToBoxAdapter(child: _buildSectionHeader('精选推荐', theme)),
        _buildProductSliverGrid(theme),
        if (_recommendedProducts.isNotEmpty || _isLoadingRecommendations) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('猜你喜欢', theme)),
          _buildRecommendedProductsGrid(theme),
        ],
      ],
    );
  }

  /// 移动端底部导航点击事件处理
  void _onMobileBottomNavItemTapped(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyOrdersPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ShoppingCartPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BillsPage()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserInfoPage()),
        );
        break;
    }
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlobalSearchPage()),
                );
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '搜索商品名称或描述...',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ShoppingCartPage()),
                  );
                },
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: const Text(
                    '0',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.chat_bubble_outline,
              color: theme.colorScheme.onSurface,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoleButton(StoreRole.client, '客户端', Icons.person, theme),
          const SizedBox(width: 8),
          _buildRoleButton(StoreRole.merchant, '商家', Icons.store, theme),
          const SizedBox(width: 8),
          _buildRoleButton(StoreRole.admin, '管理员', Icons.admin_panel_settings, theme),
        ],
      ),
    );
  }

  Widget _buildRoleButton(StoreRole role, String label, IconData icon, ThemeData theme) {
    final isSelected = _currentRole == role;
    return Expanded(
      child: Material(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _currentRole = role),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleContent(ThemeData theme) {
    switch (_currentRole) {
      case StoreRole.client:
        return _buildClientContent(theme);
      case StoreRole.merchant:
        return const MerchantDashboardPage();
      case StoreRole.admin:
        return const AdminDashboardPage();
    }
  }

  Widget _buildClientFeatureNav(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的折叠标题栏
          GestureDetector(
            onTap: () {
              setState(() {
                _isFeatureNavCollapsed = !_isFeatureNavCollapsed;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '我的服务',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AnimatedRotation(
                  turns: _isFeatureNavCollapsed ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 展开时显示功能网格
          if (!_isFeatureNavCollapsed) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feature = _features[index];
                return _buildFeatureItem(
                  icon: feature['icon'] as IconData,
                  label: feature['label'] as String,
                  page: feature['page'] as Widget,
                  badgeCount: feature['badgeCount'] as int? ?? 0,
                  theme: theme,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required Widget page,
    int badgeCount = 0,
    required ThemeData theme,
  }) {
    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: theme.colorScheme.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(ThemeData theme) {
    final quickAccessItems = [
      {'icon': Icons.apps, 'label': '全部', 'index': 0},
      {'icon': Icons.stars, 'label': '积分兑换', 'index': 1},
      {'icon': Icons.local_fire_department, 'label': '限时优惠', 'index': 2},
      {'icon': Icons.phone_android, 'label': '虚拟商品', 'index': 3},
      {'icon': Icons.leaderboard, 'label': '榜单', 'index': 5},
      {'icon': Icons.more_horiz, 'label': '更多', 'index': 4},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickAccessItems.map((item) {
          return _buildQuickAccessItem(
            icon: item['icon'] as IconData,
            label: item['label'] as String,
            index: item['index'] as int,
            theme: theme,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickAccessItem({
    required IconData icon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          // 全部 - 仅筛选
          setState(() {
            _selectedFilterIndex = 0;
          });
        } else {
          // 其他入口 - 跳转到对应页面
          Widget targetPage;
          switch (index) {
            case 1:
              targetPage = PointsExchangePage();
              break;
            case 2:
              targetPage = LimitedDealsPage();
              break;
            case 3:
              targetPage = VirtualProductsPage();
              break;
            case 4:
              targetPage = MoreFeaturesPage();
              break;
            case 5:
              targetPage = const RankingPage();
              break;
            default:
              return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetPage),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.15)
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                Text(
                  '查看更多',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSliverGrid(ThemeData theme) {
    final filteredRewards = _filteredRewards;

    if (filteredRewards.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '未找到匹配的商品',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = filteredRewards[index];
            return _buildProductCard(product, theme);
          },
          childCount: filteredRewards.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(StarProduct product, ThemeData theme) {
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (product.tags.isNotEmpty && product.tags.first.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.tags.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (!product.isActive)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '已下架',
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
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '✨',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        product.points.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (product.price > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '¥${product.price}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '已售 ${product.totalSales}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      if (product.stock > 0 && product.stock < 50)
                        Text(
                          '库存紧张',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
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

  /// 构建顶部AppBar
  AppBar _buildAppBar() {
    final theme = ref.watch(currentThemeProvider);
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Text(
        '星星商店',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
          color: theme.colorScheme.surfaceVariant,
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                '━━━ 客户版功能 ━━━',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'myOrders',
              child: Text(
                '我的订单',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyOrdersPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'favoriteProducts',
              child: Text(
                '我的收藏',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteProductsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'browsingHistory',
              child: Text(
                '浏览足迹',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BrowsingHistoryPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'clientPaymentRecords',
              child: Text(
                '支付记录',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ClientPaymentRecordsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'bills',
              child: Text(
                '账单',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              enabled: false,
              child: Text(
                '━━━ 商家版功能 ━━━',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'merchantOrders',
              child: Text(
                '订单管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MerchantOrderManagementPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'productManagement',
              child: Text(
                '商品管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MerchantProductManagementPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'productReview',
              child: Text(
                '商品审核',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductReviewPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'productReviewManagement',
              child: Text(
                '评价管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductReviewManagementPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'stockRecords',
              child: Text(
                '库存记录',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StockRecordsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'logistics',
              child: Text(
                '物流管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LogisticsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'merchantPaymentRecords',
              child: Text(
                '支付记录',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MerchantPaymentRecordsPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'merchantFinance',
              child: Text(
                '财务统计',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MerchantFinancePage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              enabled: false,
              child: Text(
                '━━━ 系统管理 ━━━',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'merchantManagement',
              child: Text(
                '商家管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MerchantManagementPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'couponManagement',
              child: Text(
                '优惠券管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CouponManagementPage(),
                    ),
                  );
                });
              },
            ),
            PopupMenuItem(
              value: 'redPacketManagement',
              child: Text(
                '红包管理',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RedPacketManagementPage(),
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建推荐商品网格
  Widget _buildRecommendedProductsGrid(ThemeData theme) {
    if (_isLoadingRecommendations) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  '加载推荐中...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_recommendedProducts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _recommendedProducts[index];
            return _buildRecommendedProductCard(product, theme);
          },
          childCount: _recommendedProducts.length,
        ),
      ),
    );
  }

  /// 构建推荐商品卡片
  Widget _buildRecommendedProductCard(StarProduct product, ThemeData theme) {
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                    child: ImageLoaderService.getImageProvider(product.image).toString().isNotEmpty
                        ? Image(
                            image: ImageLoaderService.getImageProvider(product.image),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40),
                          ),
                  ),
                ),
                if (product.tags.isNotEmpty && product.tags.first.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.tags.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '¥${product.price}',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.points > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${product.points}积分',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '已售${product.totalSales}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
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

  Widget _buildBalanceSection() {
    final theme = ref.watch(currentThemeProvider);
    final points = ref.watch(userPointsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '当前余额',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '✨',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Text(
              points.toInt().toString(),
              style: TextStyle(
                fontSize: 40,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建筛选标签区域
  Widget _buildFilterSection() {
    final theme = ref.watch(currentThemeProvider);
    final scrollController = ScrollController();
    return Container(
      width: double.infinity, // 确保宽度充满父容器
      height: 60, // 足够的高度供手势识别
      color: theme.scaffoldBackgroundColor, // 使用主题背景色
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true, // 显示滚动条，便于用户知道可以滚动
        trackVisibility: true,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            // 为不同平台配置不同的物理滚动特性
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _filters.length, // 不显示添加分类按钮
            itemBuilder: (context, index) {
              // 显示分类标签

              // 否则显示分类标签
              final filterIndex = index;
              final isSelected = _selectedFilterIndex == filterIndex;
              final categoryName = _filters[filterIndex];
              final isAllCategory = filterIndex == 0;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilterIndex = filterIndex;
                    });
                  },
                  // 移除长按显示删除按钮的功能
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 15,
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        ),
                      ),
                  ),
                ),
              );
            },
          ),
        ), // 闭合 ScrollConfiguration
      ), // 闭合 Scrollbar
    ); // 闭合 Container
  }

  Widget _buildActivityCarousel() {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildActivityCard(_activities[_currentActivityIndex]),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_activities.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentActivityIndex == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentActivityIndex == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final theme = ref.watch(currentThemeProvider);
    return GestureDetector(
      key: ValueKey(activity['title']),
      onTap: () {
        final title = activity['title'] as String;
        if (title == '限时优惠') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LimitedDealsPage()),
          );
        } else if (title == '新品上市') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GlobalSearchPage(initialQuery: '新品')),
          );
        } else if (title == '积分兑换') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PointsExchangePage()),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: (activity['color'] as Color).withOpacity(0.15),
          border: Border.all(
            color: (activity['color'] as Color).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: activity['color'] as Color,
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      activity['title'] as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity['description'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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

  /// 构建奖励卡片网格
  Widget _buildRewardsGrid() {
    final filteredRewards = _filteredRewards;
    final theme = ref.watch(currentThemeProvider);

    if (filteredRewards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '未找到匹配的商品',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '尝试其他关键词或清除搜索条件',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度动态调整卡片大小和间距
        double maxCrossAxisExtent = 200;
        double spacing = 16;

        // 手机端适配
        if (constraints.maxWidth < 600) {
          maxCrossAxisExtent = 150; // 手机端卡片宽度
        }
        // 平板端适配
        else if (constraints.maxWidth < 1000) {
          maxCrossAxisExtent = 180; // 平板端卡片宽度
        }
        // PC端适配
        else {
          maxCrossAxisExtent = 220; // PC端卡片宽度
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.7, // 调整宽高比，使卡片更协调
          ),
          itemCount: filteredRewards.length,
          itemBuilder: (context, index) {
            final reward = filteredRewards[index];
            return _buildRewardCard(reward);
          },
        );
      },
    );
  }

  /// 构建奖励卡片
  Widget _buildRewardCard(StarProduct reward) {
    // 简单的图标映射，实际项目中可以从数据库获取图标信息
    IconData getIconForReward() {
      return Icons.local_mall; // 默认图标
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据卡片宽度动态计算各元素尺寸
        final cardWidth = constraints.maxWidth;
        final padding = cardWidth * 0.04; // 动态内边距
        final iconSize = cardWidth * 0.07; // 动态图标大小
        final fontSize = cardWidth * 0.065; // 动态字体大小
        final pointsFontSize = cardWidth * 0.055; // 动态积分字体大小
        final buttonFontSize = cardWidth * 0.055; // 动态按钮字体大小
        final buttonPadding = cardWidth * 0.025; // 动态按钮内边距
        final spacing = cardWidth * 0.015; // 动态间距

        // 计算图片高度，确保有足够空间显示其他内容
        final imageHeight = cardWidth * 0.83; // 进一步减小图片高度，解决最后的溢出问题
        final theme = ref.watch(currentThemeProvider);

        return GestureDetector(
          onTap: () {
            // 导航到商品详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(product: reward),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardWidth * 0.08), // 动态圆角
              border: Border.all(color: theme.colorScheme.outline),
              color: theme.colorScheme.surfaceVariant,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // 卡片高度自适应内容
              children: [
                // 卡片图片 - 自适应卡片大小
                SizedBox(
                  height: imageHeight,
                  child: Stack(
                    fit: StackFit.expand, // 确保Stack填满可用空间
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(cardWidth * 0.08)), // 动态圆角
                        child: Image(
                          image:
                              ImageLoaderService.getImageProvider(reward.image),
                          fit: BoxFit.cover, // 使用cover确保图片填充整个容器
                          alignment: Alignment.center, // 居中显示
                          errorBuilder: (context, error, stackTrace) {
                            // 图片加载失败时显示占位符
                            return Container(
                              color: const Color(0xFF2A4532),
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: cardWidth * 0.2, // 动态图标大小
                              ),
                            );
                          },
                        ),
                      ),
                      if (!reward.isActive) ...[
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(cardWidth * 0.08)), // 动态圆角
                            color: const Color(0xFF102216).withOpacity(0.4),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: cardWidth * 0.2, // 动态锁定图标大小
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        top: padding,
                        right: padding,
                        child: Container(
                          width: cardWidth * 0.15, // 动态图标容器大小
                          height: cardWidth * 0.15, // 动态图标容器大小
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                cardWidth * 0.075), // 动态圆角
                            color: Colors.black.withOpacity(0.4),
                          ),
                          child: Icon(
                            getIconForReward(),
                            color: Colors.white,
                            size: iconSize, // 动态图标大小
                          ),
                        ),
                      ),
                      // 移除编辑和删除按钮
                    ],
                  ),
                ),
                // 卡片内容 - 自适应卡片大小
                Padding(
                  padding: EdgeInsets.all(padding), // 动态内边距
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // 内容高度自适应
                    children: [
                      // 商品名称 - 自适应卡片大小
                      SizedBox(
                        height: fontSize * 2.2, // 固定高度，确保文本不会溢出
                        child: Text(
                          reward.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis, // 处理长文本
                          maxLines: 2, // 最多显示2行
                        ),
                      ),

                      SizedBox(height: spacing * 0.8),

                      // 价格显示 - 自适应卡片大小，支持多种支付方式，根据商家指定的价格方式显示
                      _buildPriceDisplay(reward, pointsFontSize, spacing),

                      SizedBox(height: spacing * 1.2),

                      // 立即兑换按钮 - 自适应卡片大小
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: !reward.isActive
                              ? null
                              : () {
                                  // 处理兑换逻辑
                                  _handleExchange(reward);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !reward.isActive
                                ? theme.colorScheme.surfaceVariant
                                : theme.colorScheme.primary,
                            foregroundColor:
                                !reward.isActive ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(
                                vertical: buttonPadding), // 动态按钮内边距
                            minimumSize: Size.zero, // 允许按钮收缩到最小尺寸
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap, // 减小点击目标大小
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  cardWidth * 0.04), // 动态圆角
                            ),
                          ),
                          child: Text(
                            !reward.isActive ? '已锁定' : '立即兑换',
                            style: TextStyle(
                              fontSize: buttonFontSize,
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
      },
    );
  }

  /// 构建价格显示，根据商家指定的价格方式显示对应的支付方式
  Widget _buildPriceDisplay(
      StarProduct reward, double fontSize, double spacing) {
    final theme = ref.watch(currentThemeProvider);
    final isActive = reward.isActive;
    final activeColor = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    // 根据商品支持的支付方式显示对应的价格
    List<Widget> priceWidgets = [];

    // 检查并添加现金支付方式
    if (reward.supportCashPayment) {
      priceWidgets.add(Row(
        children: [
          Text(
            '¥${reward.price}',
            style: TextStyle(
              color: activeColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ));
    }

    // 检查并添加积分支付方式
    if (reward.supportPointsPayment) {
      priceWidgets.add(Row(
        children: [
          Text(
            '✨${reward.points}',
            style: TextStyle(
              color: activeColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ));
    }

    // 检查并添加混合支付方式
    if (reward.supportHybridPayment) {
      final hybridPrice = 
          reward.hybridPrice > 0 ? reward.hybridPrice : reward.price ~/ 2;
      final hybridPoints = 
          reward.hybridPoints > 0 ? reward.hybridPoints : reward.points ~/ 2;

      priceWidgets.add(Row(
        children: [
          Text(
            '¥$hybridPrice + ✨$hybridPoints',
            style: TextStyle(
              color: activeColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ));
    }

    // 如果没有支付方式，显示空容器
    if (priceWidgets.isEmpty) {
      return const SizedBox(height: 40); // 保持固定高度，避免卡片高度不一致
    }

    // 无论有多少种支付方式，都使用Column布局，保持一致的外观
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < priceWidgets.length; i++)
          Column(
            children: [
              priceWidgets[i],
              if (i < priceWidgets.length - 1) SizedBox(height: spacing * 0.3),
            ],
          ),
        // 添加一个占位符，确保价格区域高度一致
        if (priceWidgets.length == 1)
          SizedBox(height: fontSize * 1.2), // 为单个支付方式添加额外空间
      ],
    );
  }



  /// 生成18位订单ID
  /// 格式：时间戳+业务流水+用户基因段
  String _generateOrderId() {
    final now = DateTime.now();

    // 1. 时间戳：10位，精确到秒
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;

    // 2. 业务流水：4位，随机生成
    final businessFlow =
        (1000 + (now.millisecondsSinceEpoch % 9000)).toString();

    // 3. 用户基因段：4位，基于设备信息或固定值
    // 实际应用中可以使用设备ID、用户ID等生成
    final userGene = '1234'; // 模拟用户基因段

    // 组合生成18位订单ID
    return '${timestamp.toString().padLeft(10, '0')}$businessFlow$userGene';
  }

  /// 显示支付对话框
  Future<void> _showPaymentDialog(StarProduct product) async {
    // 查询商品促销活动
    List<Promotion> productPromotions = [];
    try {
      final productDb = ProductDatabaseService();
      final productId = product.id;
      if (productId != null) {
        final promoResults = await productDb.getActivePromotionsByProductId(productId);
        productPromotions = promoResults.map((map) => Promotion.fromMap(map)).toList();
      }
    } catch (e) {
      debugPrint('查询促销活动失败: $e');
    }

    // 收集商品支持的支付方式
    List<PaymentMethod> availablePaymentMethods = [];
    if (product.supportPointsPayment) {
      availablePaymentMethods.add(PaymentMethod.points);
    }
    if (product.supportCashPayment) {
      availablePaymentMethods.add(PaymentMethod.cash);
    }
    if (product.supportHybridPayment) {
      availablePaymentMethods.add(PaymentMethod.hybrid);
    }

    // 如果没有可用支付方式，显示错误信息
    if (availablePaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该商品暂无可用支付方式')),
      );
      return;
    }

    // 默认选择第一种支付方式
    PaymentMethod selectedPaymentMethod = availablePaymentMethods.first;

    // 默认数量为1
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = ref.watch(currentThemeProvider);
            return AlertDialog(
              backgroundColor: theme.colorScheme.background,
              title: Text(
                '选择支付方式',
                style: TextStyle(color: theme.colorScheme.onBackground),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.8, // 设置最大高度为屏幕高度的80%
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 商品信息
                      ListTile(
                        leading: Image(
                          image:
                              ImageLoaderService.getImageProvider(product.image),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(color: theme.colorScheme.onBackground),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // 数量编辑
                            Row(
                              children: [
                                Text(
                                  '数量: ',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (quantity > 1) {
                                      setState(() {
                                        quantity--;
                                      });
                                    }
                                  },
                                  icon: Icon(Icons.remove,
                                      color: theme.colorScheme.onSurface),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32),
                                ),
                                Text(
                                  quantity.toString(),
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (quantity < product.stock) {
                                      setState(() {
                                        quantity++;
                                      });
                                    }
                                  },
                                  icon:
                                      Icon(Icons.add, color: theme.colorScheme.onSurface),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '库存: ${product.stock}',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: theme.colorScheme.outline),

                      // 优惠券、红包和购物卡选择
                      Column(
                        children: [
                          // 优惠券选择
                        ListTile(
                          title: Text(
                            '选择优惠券',
                            style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _selectedCoupons.isNotEmpty ? '已选择: ${_selectedCoupons.length}张优惠券' : '未选择优惠券',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                          trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                          onTap: () async {
                            // 打开优惠券选择界面
                            final databaseService = DatabaseService();
                            final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                            final selectedCoupons = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CouponsDetailPage(
                                  userId: userId,
                                  selectMode: true,
                                  selectedCoupons: _selectedCoupons,
                                ),
                              ),
                            );
                            if (selectedCoupons != null) {
                              setState(() {
                                if (selectedCoupons is List) {
                                  _selectedCoupons = selectedCoupons.cast<Map<String, dynamic>>();
                                } else if (selectedCoupons is Map) {
                                  _selectedCoupons = [selectedCoupons.cast<String, dynamic>()];
                                }
                              });
                            }
                          },
                            tileColor: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: theme.colorScheme.outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 红包选择
                          GestureDetector(
                            onTap: () async {
                              // 打开红包选择界面
                              final databaseService = DatabaseService();
                              final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                              final selectedRedPackets = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CouponsDetailPage(
                                  userId: userId,
                                  selectMode: true,
                                  selectType: 'red_packet',
                                  selectedRedPackets: _selectedRedPackets,
                                ),
                              ),
                            );
                              if (selectedRedPackets != null) {
                                setState(() {
                                  if (selectedRedPackets is List) {
                                    _selectedRedPackets = selectedRedPackets.cast<Map<String, dynamic>>();
                                  } else if (selectedRedPackets is Map) {
                                    _selectedRedPackets = [selectedRedPackets.cast<String, dynamic>()];
                                  }
                                  // 按金额从小到大和快要到期的优先排序
                                  _selectedRedPackets.sort((a, b) {
                                    // 先按金额排序
                                    final amountA = a['amount'] is num ? (a['amount'] as num).toDouble() : 0.0;
                                    final amountB = b['amount'] is num ? (b['amount'] as num).toDouble() : 0.0;
                                    if (amountA != amountB) {
                                      return amountA.compareTo(amountB);
                                    }
                                    // 金额相同按到期时间排序
                                    final validityA = a['validity'] as String? ?? '';
                                    final validityB = b['validity'] as String? ?? '';
                                    if (validityA == '永久' && validityB != '永久') return -1;
                                    if (validityA != '永久' && validityB == '永久') return 1;
                                    if (validityA != '永久' && validityB != '永久') {
                                      final dateA = DateTime.tryParse(validityA);
                                      final dateB = DateTime.tryParse(validityB);
                                      if (dateA != null && dateB != null) {
                                        return dateA.compareTo(dateB);
                                      }
                                    }
                                    return 0;
                                  });
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '选择红包',
                                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _selectedRedPackets.isNotEmpty ? '已选择: ${_selectedRedPackets.length}个红包' : '未选择红包',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 购物卡选择
                          GestureDetector(
                            onTap: () async {
                              // 打开购物卡选择界面
                              final databaseService = DatabaseService();
                              final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                              final selectedShoppingCards = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShoppingCardPage(
                                  userId: userId,
                                  selectMode: true,
                                  selectedShoppingCards: _selectedShoppingCards,
                                ),
                              ),
                            );
                              if (selectedShoppingCards != null) {
                                setState(() {
                                  if (selectedShoppingCards is List) {
                                    _selectedShoppingCards = selectedShoppingCards.cast<Map<String, dynamic>>();
                                  } else if (selectedShoppingCards is Map) {
                                    _selectedShoppingCards = [selectedShoppingCards.cast<String, dynamic>()];
                                  }
                                  // 按金额从小到大和快要到期的优先排序
                                  _selectedShoppingCards.sort((a, b) {
                                    // 先按金额排序
                                    final amountA = a['amount'] is num ? (a['amount'] as num).toDouble() : 0.0;
                                    final amountB = b['amount'] is num ? (b['amount'] as num).toDouble() : 0.0;
                                    if (amountA != amountB) {
                                      return amountA.compareTo(amountB);
                                    }
                                    // 金额相同按到期时间排序
                                    final validityA = a['validity'] as String? ?? '';
                                    final validityB = b['validity'] as String? ?? '';
                                    if (validityA == '永久' && validityB != '永久') return -1;
                                    if (validityA != '永久' && validityB == '永久') return 1;
                                    if (validityA != '永久' && validityB != '永久') {
                                      final dateA = DateTime.tryParse(validityA);
                                      final dateB = DateTime.tryParse(validityB);
                                      if (dateA != null && dateB != null) {
                                        return dateA.compareTo(dateB);
                                      }
                                    }
                                    return 0;
                                  });
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '选择购物卡',
                                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _selectedShoppingCards.isNotEmpty ? '已选择: ${_selectedShoppingCards.length}张购物卡' : '未选择购物卡',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),



                      // 优惠和合计信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // 计算优惠金额
                              Text(
                                '${_calculateDiscountInfo((product.price * quantity).toDouble(), (product.points * quantity).toDouble(), selectedPaymentMethod, _selectedCoupons, _selectedRedPackets, _selectedShoppingCards, promotions: productPromotions)}',
                                style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              // 计算合计金额
                              Text(
                                '${_calculateTotalInfo((product.price * quantity).toDouble(), (product.points * quantity).toDouble(), selectedPaymentMethod, _selectedCoupons, _selectedRedPackets, _selectedShoppingCards, promotions: productPromotions)}',
                                style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 支付方式选择
                      Text(
                        '请选择支付方式',
                        style: TextStyle(
                            color: theme.colorScheme.onBackground,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // 支付方式列表
                      ...availablePaymentMethods.map((method) {
                        String methodText;
                        String priceText;
                        Color color = theme.colorScheme.primary;

                        // 计算支付金额，考虑优惠券和红包
                        int totalCash = 0;
                        int totalPoints = 0;

                        switch (method) {
                          case PaymentMethod.points:
                            methodText = '积分支付';
                            totalPoints = product.points * quantity;
                            // 应用优惠券
                            for (final coupon in _selectedCoupons) {
                              final couponRewardType = coupon['reward_type'] ?? 'cash';
                              if (couponRewardType == 'points') {
                                if (coupon['type'] == '满减券') {
                                  final couponAmount = (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  totalPoints -= couponAmount;
                                  if (totalPoints < 0) totalPoints = 0;
                                } else if (coupon['type'] == '折扣券') {
                                  totalPoints = (totalPoints * (coupon['discount'] ?? 1.0)).round();
                                } else if (coupon['type'] == '无门槛券') {
                                  final couponAmount = (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  totalPoints -= couponAmount;
                                  if (totalPoints < 0) totalPoints = 0;
                                } else if (coupon['type'] == '星星券') {
                                  final couponAmount = (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  totalPoints -= couponAmount;
                                  if (totalPoints < 0) totalPoints = 0;
                                }
                              }
                            }
                            // 应用红包（仅积分红包适用于积分支付）
                        for (final redPacket in _selectedRedPackets) {
                              if (redPacket['reward_type'] == 'points') {
                                final redPacketAmount = (redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0);
                                totalPoints -= redPacketAmount;
                                if (totalPoints < 0) totalPoints = 0;
                              }
                            }
                            // 购物卡不影响积分支付
                            priceText = '✨${totalPoints}';
                            break;
                          case PaymentMethod.cash:
                            methodText = '现金支付';
                            totalCash = product.price * quantity;
                            // 应用优惠券和红包
                            for (final coupon in _selectedCoupons) {
                              final couponRewardType = coupon['reward_type'] ?? 'cash';
                              if (couponRewardType == 'cash') {
                                if (coupon['type'] == '满减券') {
                                  totalCash -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalCash < 0) totalCash = 0;
                                } else if (coupon['type'] == '折扣券') {
                                  totalCash = (totalCash * (coupon['discount'] ?? 1.0)).round();
                                } else if (coupon['type'] == '无门槛券') {
                                  totalCash -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalCash < 0) totalCash = 0;
                                }
                              }
                            }
                            for (final redPacket in _selectedRedPackets) {
                              if (redPacket['reward_type'] == 'cash') {
                                totalCash -= (redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0);
                                if (totalCash < 0) totalCash = 0;
                              }
                            }
                            if (_selectedShoppingCards.isNotEmpty) {
                              totalCash = 0;
                            }
                            priceText = '¥${totalCash}';
                            break;
                          case PaymentMethod.hybrid:
                            methodText = '混合支付';
                            final hybridPrice = product.hybridPrice > 0
                                ? product.hybridPrice
                                : product.price ~/ 2;
                            final hybridPoints = product.hybridPoints > 0
                                ? product.hybridPoints
                                : product.points ~/ 2;
                            totalCash = hybridPrice * quantity;
                            totalPoints = hybridPoints * quantity;
                            // 应用优惠券和红包
                            for (final coupon in _selectedCoupons) {
                              final couponRewardType = coupon['reward_type'] ?? 'cash';
                              if (couponRewardType == 'cash') {
                                if (coupon['type'] == '满减券') {
                                  totalCash -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalCash < 0) totalCash = 0;
                                } else if (coupon['type'] == '折扣券') {
                                  totalCash = (totalCash * (coupon['discount'] ?? 1.0)).round();
                                } else if (coupon['type'] == '无门槛券') {
                                  totalCash -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalCash < 0) totalCash = 0;
                                }
                              } else {
                                if (coupon['type'] == '满减券') {
                                  totalPoints -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalPoints < 0) totalPoints = 0;
                                } else if (coupon['type'] == '折扣券') {
                                  totalPoints = (totalPoints * (coupon['discount'] ?? 1.0)).round();
                                } else if (coupon['type'] == '无门槛券') {
                                  totalPoints -= (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
                                  if (totalPoints < 0) totalPoints = 0;
                                }
                              }
                            }
                            for (final redPacket in _selectedRedPackets) {
                              if (redPacket['reward_type'] == 'cash') {
                                totalCash -= (redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0);
                                if (totalCash < 0) totalCash = 0;
                              } else {
                                totalPoints -= (redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0);
                                if (totalPoints < 0) totalPoints = 0;
                              }
                            }
                            if (_selectedShoppingCards.isNotEmpty) {
                              totalCash = 0;
                            }
                            priceText = 
                                '¥${totalCash} + ✨${totalPoints}';
                            break;
                          case PaymentMethod.shoppingCard:
                            methodText = '购物卡支付';
                            priceText = '💳';
                            break;
                        }

                        return RadioListTile<PaymentMethod>(
                          value: method,
                          groupValue: selectedPaymentMethod,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedPaymentMethod = value;
                              });
                            }
                          },
                          title: Text(
                            methodText,
                            style: TextStyle(color: theme.colorScheme.onBackground),
                          ),
                          subtitle: Text(
                            priceText,
                            style: TextStyle(color: color),
                          ),
                          activeColor: theme.colorScheme.primary,
                          tileColor: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.colorScheme.outline),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    if (_isProcessing) return;
                    setState(() { _isProcessing = true; });
                    Navigator.pop(context);
                    await _handlePayment(product, selectedPaymentMethod, quantity, 
                      selectedCoupons: _selectedCoupons, 
                      selectedRedPackets: _selectedRedPackets,
                      selectedShoppingCards: _selectedShoppingCards);
                    if (mounted) {
                      setState(() { _isProcessing = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: Text('确认支付'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 处理支付逻辑
  Future<void> _handlePayment(
      StarProduct product, PaymentMethod paymentMethod, int quantity, 
      {List<Map<String, dynamic>>? selectedCoupons, List<Map<String, dynamic>>? selectedRedPackets, List<Map<String, dynamic>>? selectedShoppingCards}) async {
    try {
      // 检查商品库存是否足够
      if (product.stock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品库存不足，无法兑换'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 获取当前用户ID
      final databaseService = DatabaseService();
      final productDatabaseService = ProductDatabaseService();
      final userId = await databaseService.getCurrentUserId() ?? 'default_user';

      final buyerExtension = await databaseService.getBuyerExtension(userId);
      final defaultAddress = await databaseService.getDefaultAddress(userId);

      final buyerName = (buyerExtension?['nickname'] ?? '') as String;
      final buyerPhone = (buyerExtension?['phone'] ?? '') as String;
      String deliveryAddress = '';
      if (defaultAddress != null) {
        final province = (defaultAddress['province'] ?? '') as String;
        final city = (defaultAddress['city'] ?? '') as String;
        final district = (defaultAddress['district'] ?? '') as String;
        final detail = (defaultAddress['detail'] ?? '') as String;
        final addressName = (defaultAddress['name'] ?? '') as String;
        final addressPhone = (defaultAddress['phone'] ?? '') as String;
        deliveryAddress = '$province$city$district$detail';
        if (addressName.isNotEmpty) {
          deliveryAddress = '$addressName $addressPhone\n$deliveryAddress';
        }
      }

      // 保存原始金额用于订单记录
      double originalPoints = 0.0;
      int originalCash = 0;

      // 根据支付方式计算支付金额和积分
      double points = 0.0;
      int cash = 0;

      switch (paymentMethod) {
        case PaymentMethod.points:
          points = (product.points * quantity).toDouble();
          cash = 0;
          break;
        case PaymentMethod.cash:
          points = 0.0;
          cash = product.price * quantity;
          break;
        case PaymentMethod.hybrid:
          final hybridPrice = product.hybridPrice > 0
              ? product.hybridPrice
              : product.price ~/ 2;
          final hybridPoints = product.hybridPoints > 0
              ? product.hybridPoints
              : product.points ~/ 2;
          points = (hybridPoints * quantity).toDouble();
          cash = hybridPrice * quantity;
          break;
        case PaymentMethod.shoppingCard:
          points = 0.0;
          cash = 0;
          break;
      }

      // 保存原始金额用于订单记录
      originalPoints = points;
      originalCash = cash;

      // 应用促销活动折扣
      int promotionDiscount = 0;
      try {
        final productId = product.id;
        if (productId != null) {
          final promoResults = await productDatabaseService.getActivePromotionsByProductId(productId);
          for (final promoMap in promoResults) {
            final promo = Promotion.fromMap(promoMap);
            if (promo.type == 'full_reduction') {
              final totalAmount = cash + (points / 100).round();
              if (totalAmount >= promo.thresholdAmount) {
                final reduction = promo.discountValue.toInt();
                promotionDiscount += reduction;
                if (cash > 0) {
                  cash -= reduction;
                  if (cash < 0) cash = 0;
                } else {
                  points -= reduction * 100;
                  if (points < 0) points = 0;
                }
              }
            } else if (promo.type == 'discount') {
              final discountRate = promo.discountValue / 100;
              final originalCash = cash;
              final originalPoints = points;
              cash = (cash * discountRate).round();
              points = points * discountRate;
              promotionDiscount += (originalCash - cash) + ((originalPoints - points) / 100).round();
            }
          }
        }
      } catch (e) {
        debugPrint('应用促销活动失败: $e');
      }

      if (promotionDiscount > 0) {
        debugPrint('促销活动折扣: $promotionDiscount');
      }
      
      // 检查积分是否足够（如果使用积分支付）
      if (points > 0) {
        final currentPoints = await databaseService.getUserPoints(userId);
        if (currentPoints < points) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('积分不足，当前积分: ${currentPoints.toInt()}，需要积分: ${points.toInt()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // 应用优惠券
      int couponDiscount = 0;
      if (selectedCoupons != null && selectedCoupons.isNotEmpty) {
        for (final coupon in selectedCoupons) {
        // 检查优惠券有效期
        final validity = coupon['validity'] as String? ?? '';
        if (validity != '永久') {
          final validityDate = DateTime.tryParse(validity);
          if (validityDate == null || validityDate.isBefore(DateTime.now())) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('优惠券已过期，无法使用'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // 检查优惠券使用条件
        final couponCondition = coupon['condition'] is num ? (coupon['condition'] as num).toInt() : 0;
        // 对于积分支付，将积分转换为现金价值进行条件检查
        final totalValue = cash + (points / 100); // 假设100积分=1元
        if (totalValue < couponCondition) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('订单金额未达到优惠券使用条件'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // 应用优惠券折扣
        final couponRewardType = coupon['reward_type'] ?? 'cash';
        if (coupon['type'] == '满减券') {
          final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0;
          couponDiscount += couponAmount;
          if (couponRewardType == 'points') {
            points -= couponAmount * 100;
            if (points < 0) points = 0;
          } else {
            if (cash > 0) {
              cash -= couponAmount;
              if (cash < 0) cash = 0;
            } else {
              points -= couponAmount * 100;
              if (points < 0) points = 0;
            }
          }
        } else if (coupon['type'] == '折扣券') {
          final discount = coupon['discount'] is num ? (coupon['discount'] as num) : 1.0;
          if (couponRewardType == 'points') {
            points = points * discount;
            couponDiscount += (originalPoints ~/ 100) - (points ~/ 100);
          } else {
            cash = (cash * discount).round();
            points = points * discount;
            couponDiscount += (originalCash + (originalPoints ~/ 100)) - (cash + (points ~/ 100));
          }
        } else if (coupon['type'] == '无门槛券') {
          final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0;
          couponDiscount += couponAmount;
          if (couponRewardType == 'points') {
            points -= couponAmount * 100;
            if (points < 0) points = 0;
          } else {
            if (cash > 0) {
              cash -= couponAmount;
              if (cash < 0) cash = 0;
            } else {
              points -= couponAmount * 100;
              if (points < 0) points = 0;
            }
          }
        }
        }
      }

      // 应用红包或购物卡
      int redPacketDiscount = 0;
      int shoppingCardDiscount = 0;

      // 开始事务
      // 1. 生成18位订单ID：时间戳+业务流水+用户基因段
      final orderId = _generateOrderId();

      // 应用红包
      if (selectedRedPackets != null && selectedRedPackets.isNotEmpty) {
        for (final redPacket in selectedRedPackets) {
          // 检查红包有效期
          final validity = redPacket['validity'] as String? ?? '';
          if (validity != '永久') {
            final validityDate = DateTime.tryParse(validity);
            if (validityDate == null || validityDate.isBefore(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('红包已过期，无法使用'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }

          // 应用红包金额
          final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0;

          // 检查红包类型
          final redPacketType = redPacket['reward_type'] ?? 'cash';
          if (redPacketType == 'points') {
            // 积分红包直接抵扣积分
            if (points > 0) {
              // 计算实际需要的红包金额（使用应用优惠券后的points值）
              final actualDiscount = points;
              redPacketDiscount += actualDiscount.toInt();

              // 如果需要支付积分，使用红包抵扣
              if (redPacketAmount >= actualDiscount) {
                // 红包金额足够支付全部积分
                points = 0.0;
                // 更新红包余额
                final remainingAmount = redPacketAmount - actualDiscount.toInt();
                final redPacketId = redPacket?['id'];
                if (redPacketId != null) {
                  if (remainingAmount > 0) {
                    // 红包还有剩余，只更新余额
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'amount': remainingAmount,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  } else {
                    // 红包金额刚好用完，设置为已使用
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'status': '已使用',
                          'used_at': DateTime.now().millisecondsSinceEpoch,
                          'used_order_id': orderId,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  }
                }
              } else {
                // 红包金额不够，部分抵扣
                points -= redPacketAmount;
                redPacketDiscount += redPacketAmount;
                // 红包金额全部用完，设置为已使用
                final redPacketId = redPacket?['id'];
                if (redPacketId != null) {
                  await databaseService.database.then((db) async {
                    await db.update(
                      'red_packets',
                      {
                        'status': '已使用',
                        'used_at': DateTime.now().millisecondsSinceEpoch,
                        'used_order_id': orderId,
                        'updated_at': DateTime.now().millisecondsSinceEpoch,
                      },
                      where: 'id = ?',
                      whereArgs: [redPacketId],
                    );
                  });
                }
              }
            }
          } else {
            // 现金红包
            if (cash > 0) {
              // 计算实际需要的红包金额（使用应用优惠券后的cash值）
              final actualDiscount = cash;
              redPacketDiscount += actualDiscount;

              // 使用红包抵扣现金
              if (redPacketAmount >= actualDiscount) {
                // 红包金额足够支付全部现金
                cash = 0;
                // 更新红包余额
                final remainingAmount = redPacketAmount - actualDiscount;
                final redPacketId = redPacket?['id'];
                if (redPacketId != null) {
                  if (remainingAmount > 0) {
                    // 红包还有剩余，只更新余额
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'amount': remainingAmount,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  } else {
                    // 红包金额刚好用完，设置为已使用
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'status': '已使用',
                          'used_at': DateTime.now().millisecondsSinceEpoch,
                          'used_order_id': orderId,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  }
                }
              } else {
                // 红包金额不够，部分抵扣
                cash -= redPacketAmount;
                redPacketDiscount += redPacketAmount;
                // 红包金额全部用完，设置为已使用
                final redPacketId = redPacket?['id'];
                if (redPacketId != null) {
                  await databaseService.database.then((db) async {
                    await db.update(
                      'red_packets',
                      {
                        'status': '已使用',
                        'used_at': DateTime.now().millisecondsSinceEpoch,
                        'used_order_id': orderId,
                        'updated_at': DateTime.now().millisecondsSinceEpoch,
                      },
                      where: 'id = ?',
                      whereArgs: [redPacketId],
                    );
                  });
                }
              }
            }
          }
        }
      }

      // 应用购物卡
      if (selectedShoppingCards != null && selectedShoppingCards.isNotEmpty) {
        for (final shoppingCard in selectedShoppingCards) {
          // 检查购物卡有效期
          final validity = shoppingCard['validity'] as String? ?? '';
          if (validity != '永久') {
            final validityDate = DateTime.tryParse(validity);
            if (validityDate == null || validityDate.isBefore(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡已过期，无法使用'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }

          // 检查购物卡余额
          final shoppingCardAmount = shoppingCard['amount'] is num ? (shoppingCard['amount'] as num).toInt() : 0;
          if (cash > 0) {
            if (shoppingCardAmount < cash) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡余额不足，无法支付'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // 使用购物卡支付
            shoppingCardDiscount += cash;
            // 计算购物卡剩余余额
            final remainingAmount = shoppingCardAmount - cash;
            // 更新购物卡余额
            shoppingCard['amount'] = remainingAmount;
            cash = 0;
          } else if (points > 0) {
            // 积分支付时，将积分转换为现金价值
            final pointsValue = points.toInt();
            if (shoppingCardAmount < pointsValue) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡余额不足，无法支付'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // 使用购物卡支付
            shoppingCardDiscount += pointsValue;
            // 计算购物卡剩余余额
            final remainingAmount = shoppingCardAmount - pointsValue;
            // 更新购物卡余额
            shoppingCard['amount'] = remainingAmount;
            points = 0.0;
          }

          // 更新购物卡状态
          final shoppingCardId = shoppingCard['id'] as String;
          final remainingAmount = shoppingCard['amount'] is num ? (shoppingCard['amount'] as num).toInt() : 0;
          await databaseService.database.then((db) async {
            await db.update(
              'shopping_cards',
              {
                'amount': remainingAmount,
                'status': remainingAmount > 0 ? '可用' : '已使用',
                'used_at': DateTime.now().millisecondsSinceEpoch,
                'used_order_id': orderId,
                'used_date': DateTime.now().toString().substring(0, 10),
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [shoppingCardId],
            );
          });
        }
      }

      // 显示确认窗口
      final confirmExchange = await _showExchangeConfirmationDialog(
          product, quantity, paymentMethod);

      if (!confirmExchange) {
        // 用户取消兑换
        return;
      }
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // 计算各项费用
      double totalAmount = 0.0;
      int pointsUsed = 0;
      double cashAmount = 0.0;

      switch (paymentMethod) {
        case PaymentMethod.points:
          totalAmount = 0.0;
          pointsUsed = points.toInt();
          cashAmount = 0.0;
          break;
        case PaymentMethod.cash:
          totalAmount = cash.toDouble();
          pointsUsed = 0;
          cashAmount = totalAmount;
          break;
        case PaymentMethod.hybrid:
          totalAmount = cash.toDouble();
          pointsUsed = points.toInt();
          cashAmount = totalAmount;
          break;
        case PaymentMethod.shoppingCard:
          totalAmount = 0.0;
          pointsUsed = 0;
          cashAmount = 0.0;
          break;
      }

      // 2. 创建订单，状态设置为"待发货"
      final Map<String, dynamic> orderData = {
        'id': orderId,
        'user_id': userId,
        'product_id': product.id,
        'merchant_id': product.merchantId,
        'product_name': product.name,
        'product_image': product.image,
        'points': product.points,
        'product_price': product.price,
        'total_amount': totalAmount,
        'points_used': pointsUsed,
        'cash_amount': cashAmount,
        'original_points': originalPoints,
        'original_cash': originalCash,
        'payment_method': paymentMethod.storageValue,
        'quantity': quantity,
        'status': product.isElectronic ? '待确认' : '待发货',
        'is_electronic': product.isElectronic ? 1 : 0,
        'fund_status': 'escrow',
        'created_at': nowMs,
        'updated_at': nowMs,
        'buyer_name': buyerName,
        'buyer_phone': buyerPhone,
        'delivery_address': deliveryAddress,
        'buyer_note': '',
      };

      // 只有当商品有规格信息时才添加variant字段
      String variantInfo = '';
      // 目前星星商店页面没有规格选择功能，所以设置为空字符串
      if (variantInfo.isNotEmpty) {
        orderData['variant'] = variantInfo;
      }

      await productDatabaseService.insertOrder(orderData);

      // 创建并插入支付记录，以便收支显示在支付记录和财务统计中
      final paymentRecord = PaymentRecord(
        orderId: orderId,
        userId: userId,
        paymentNo: 'PAY${DateTime.now().millisecondsSinceEpoch}${DateTime.now().microsecond}',
        amount: pointsUsed + cashAmount.round(),
        pointsUsed: pointsUsed,
        cashAmount: cashAmount.round(),
        paymentMethod: paymentMethod.storageValue,
        status: 'success',
        paidAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        merchantId: product.merchantId,
        fundStatus: 'escrow',
      );
      try {
        await productDatabaseService.insertPaymentRecord(paymentRecord);
      } catch (e) {
        debugPrint('创建支付记录失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付记录保存失败: $e'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // 3. 更新商品库存
      final productId = product.id;
      if (productId != null) {
        await productDatabaseService.updateProduct(productId, {
          'stock': product.stock - quantity,
          'total_sales': product.totalSales + quantity,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        await productDatabaseService.insertStockRecord(StockRecord(
          productId: productId,
          type: 'order',
          quantity: quantity,
          stockBefore: product.stock,
          stockAfter: product.stock - quantity,
          relatedId: orderId,
          remark: '星星商店下单扣减库存',
          operatorId: userId,
          createdAt: DateTime.now(),
        ));
      }

      // 4. 扣除用户积分（如果使用积分支付）
      if (points > 0) {
        await databaseService.updateUserPoints(
          userId, 
          -points,
          description: '兑换商品: ${product.name}',
          transactionType: 'exchange',
          relatedId: orderId
        );
        ref.read(userPointsProvider.notifier).refresh();
      }

      // 5. 更新优惠券状态
      if (selectedCoupons != null && selectedCoupons.isNotEmpty) {
        for (final coupon in selectedCoupons) {
          final couponId = coupon['id'] as String;
          await databaseService.database.then((db) async {
            await db.update(
              'coupons',
              {
                'status': '已使用',
                'used_at': DateTime.now().millisecondsSinceEpoch,
                'used_order_id': orderId,
              },
              where: 'id = ?',
              whereArgs: [couponId],
            );
          });
        }
      }

      // 6. 重新加载数据
      await _loadData();

      // 8. 显示成功信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换成功，订单号: $orderId'),
          backgroundColor: const Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('兑换失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 显示添加/编辑奖励对话框
  void _showAddEditRewardDialog({StarProduct? reward}) {
    final _nameController = TextEditingController(text: reward?.name ?? '');
    final _pointsController =
        TextEditingController(text: reward?.points.toString() ?? '');
    final _imageUrlController =
        TextEditingController(text: reward?.image ?? '');
    bool _isActive = reward?.isActive ?? true;
    int? _selectedCategoryId = reward?.categoryId;

    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surfaceVariant,
              title: Text(
                reward != null ? '编辑商品' : '添加商品',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 名称输入
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: '商品名称',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A4532)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF13ec5b)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 积分输入
                      TextField(
                        controller: _pointsController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '所需积分',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A4532)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF13ec5b)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 分类选择
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '商品分类',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 改为下拉列表形式
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A4532)),
                          color: const Color(0xFF1A2C20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedCategoryId,
                            hint: const Text(
                              '选择分类',
                              style: TextStyle(color: Colors.grey),
                            ),
                            style: const TextStyle(color: Colors.white),
                            dropdownColor: const Color(0xFF1A2C20),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                            items: [
                              // 分类列表
                              ..._categories.map((category) {
                                return DropdownMenuItem<int>(
                                  value: category.id,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.category,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(category.name),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategoryId = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 图片URL输入和上传按钮
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _imageUrlController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: '图片URL或本地路径',
                                    labelStyle: TextStyle(color: Colors.grey),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Color(0xFF2A4532)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Color(0xFF13ec5b)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 图片上传按钮
                              ElevatedButton(
                                onPressed: () async {
                                  // 从相册选择图片
                                  final picker = ImagePicker();
                                  final pickedFile = await picker.pickImage(
                                      source: ImageSource.gallery);

                                  if (pickedFile != null) {
                                    try {
                                      // 存储图片到store目录
                                      final storageService = StorageService();
                                      // 使用更有意义的用户ID，这里可以根据实际情况从用户系统获取
                                      final userId =
                                          'user_123'; // 这里应该使用实际的用户ID
                                      final imagePath =
                                          await storageService.storeFile(
                                        XFile(pickedFile.path),
                                        fileType: 'images', // 使用正确的文件类型
                                        userId: userId,
                                        isStore:
                                            true, // 使用isStore参数确保图片存放在store目录
                                      );
                                      setState(() {
                                        _imageUrlController.text = imagePath;
                                      });
                                    } catch (e) {
                                      // 显示错误信息
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('图片上传失败: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13ec5b),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                ),
                                child: const Text('上传图片'),
                              ),
                            ],
                          ),
                          // 图片预览
                          if (_imageUrlController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF2A4532)),
                                image: DecorationImage(
                                  image: ImageLoaderService.getImageProvider(
                                      _imageUrlController.text),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _imageUrlController.text = '';
                                        });
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 激活状态选择
                      Row(
                        children: [
                          const Text(
                            '是否激活',
                            style: TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                            activeColor: const Color(0xFF13ec5b),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 保存商品
                    final name = _nameController.text.trim();
                    final points =
                        int.tryParse(_pointsController.text.trim()) ?? 0;
                    final image = _imageUrlController.text.trim();

                    if (name.isNotEmpty &&
                        points > 0 &&
                        image.isNotEmpty &&
                        _selectedCategoryId != null) {
                      final now = DateTime.now();

                      if (reward != null) {
                        // 编辑现有商品
                        final updatedProduct = StarProduct(
                          id: reward.id,
                          name: name,
                          description: reward.description,
                          image: image,
                          productCode: reward.productCode,
                          points: points,
                          costPrice: reward.costPrice,
                          stock: reward.stock,
                          categoryId: _selectedCategoryId!, // 使用!断言非空
                          brand: reward.brand,
                          tags: reward.tags,
                          isActive: _isActive,
                          isDeleted: reward.isDeleted,
                          status: reward.status,
                          createdAt: reward.createdAt,
                          updatedAt: now,
                          deletedAt: reward.deletedAt,
                        );

                        // 更新到数据库
                        final updatedProductId = updatedProduct.id;
                        if (updatedProductId != null) {
                          await _databaseService.updateProduct(
                            updatedProductId,
                            updatedProduct.toMap(),
                          );
                        }
                      } else {
                        // 添加新商品
                        final newProduct = StarProduct(
                          name: name,
                          description: '',
                          image: image,
                          productCode:
                              'PROD${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}',
                          points: points,
                          costPrice: 0,
                          stock: 100, // 默认库存
                          categoryId: _selectedCategoryId!, // 使用!断言非空
                          brand: '',
                          tags: [],
                          isActive: _isActive,
                          isDeleted: false,
                          status: 'active',
                          createdAt: now,
                          updatedAt: now,
                        );

                        // 插入到数据库
                        await _databaseService
                            .insertProduct(newProduct.toMap());
                      }

                      // 重新加载数据
                      await _loadData();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13ec5b),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 计算优惠信息
  String _calculateDiscountInfo(double cashAmount, double pointsAmount, PaymentMethod paymentMethod, List<Map<String, dynamic>>? selectedCoupons, List<Map<String, dynamic>> redPackets, List<Map<String, dynamic>> shoppingCards, {List<Promotion>? promotions}) {
    double discount = 0.0;
    String unit = paymentMethod == PaymentMethod.points ? '✨' : '¥';

    if (promotions != null) {
      for (final promo in promotions) {
        if (promo.type == 'full_reduction') {
          final totalAmount = paymentMethod == PaymentMethod.points
              ? pointsAmount
              : cashAmount;
          if (totalAmount >= promo.thresholdAmount) {
            discount += promo.discountValue;
          }
        } else if (promo.type == 'discount') {
          final discountRate = promo.discountValue / 100;
          if (paymentMethod == PaymentMethod.points) {
            discount += pointsAmount * (1 - discountRate);
          } else {
            discount += cashAmount * (1 - discountRate);
          }
        }
      }
    }

    // 计算优惠券折扣（只计算优惠券和满减等，不包括红包）
    if (selectedCoupons != null) {
      for (final coupon in selectedCoupons) {
        if (coupon['type'] == '满减券' || coupon['type'] == '无门槛券' || coupon['type'] == '星星券') {
          if (paymentMethod == PaymentMethod.points) {
            // 直接使用优惠券金额作为积分折扣
            discount += coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
          } else {
            discount += coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
          }
        } else if (coupon['type'] == '折扣券') {
          final discountRate = coupon['discount'] is num ? (coupon['discount'] as num).toDouble() : 1.0;
          if (paymentMethod == PaymentMethod.points) {
            discount += pointsAmount * (1 - discountRate);
          } else {
            discount += cashAmount * (1 - discountRate);
          }
        }
      }
    }

    // 积分支付时，折扣金额向上取整
    if (paymentMethod == PaymentMethod.points) {
      discount = discount.ceilToDouble();
    }

    return '优惠：$unit${discount.toStringAsFixed(paymentMethod == PaymentMethod.points ? 0 : 2)}';
  }

  /// 计算合计信息
  String _calculateTotalInfo(double cashAmount, double pointsAmount, PaymentMethod paymentMethod, List<Map<String, dynamic>>? selectedCoupons, List<Map<String, dynamic>> redPackets, List<Map<String, dynamic>> shoppingCards, {List<Promotion>? promotions}) {
    double total = 0.0;
    String unit = paymentMethod == PaymentMethod.points ? '✨' : '¥';

    // 先应用促销活动折扣
    double promoCashDiscount = 0.0;
    double promoPointsDiscount = 0.0;
    if (promotions != null) {
      for (final promo in promotions) {
        if (promo.type == 'full_reduction') {
          final totalAmount = paymentMethod == PaymentMethod.points ? pointsAmount : cashAmount;
          if (totalAmount >= promo.thresholdAmount) {
            if (paymentMethod == PaymentMethod.points) {
              promoPointsDiscount += promo.discountValue;
            } else {
              promoCashDiscount += promo.discountValue;
            }
          }
        } else if (promo.type == 'discount') {
          final discountRate = promo.discountValue / 100;
          promoCashDiscount += cashAmount * (1 - discountRate);
          promoPointsDiscount += pointsAmount * (1 - discountRate);
        }
      }
    }

    // 计算应用优惠后的价格（只应用优惠券，不包括红包和购物卡）
    switch (paymentMethod) {
      case PaymentMethod.points:
        total = pointsAmount - promoPointsDiscount;
        // 应用优惠券
        if (selectedCoupons != null) {
          // 先应用满减券、无门槛券和星星券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '满减券' || coupon['type'] == '无门槛券' || coupon['type'] == '星星券') {
              total -= coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
            }
          }
          // 再应用折扣券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '折扣券') {
              final discountRate = coupon['discount'] is num ? (coupon['discount'] as num).toDouble() : 1.0;
              total *= discountRate;
            }
          }
        }
        break;
      case PaymentMethod.cash:
        total = cashAmount - promoCashDiscount;
        // 应用优惠券
        if (selectedCoupons != null) {
          // 先应用满减券和无门槛券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '满减券' || coupon['type'] == '无门槛券') {
              total -= coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
            }
          }
          // 再应用折扣券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '折扣券') {
              final discountRate = coupon['discount'] is num ? (coupon['discount'] as num).toDouble() : 1.0;
              total *= discountRate;
            }
          }
        }
        break;
      case PaymentMethod.hybrid:
        // 混合支付时，只计算现金部分的优惠
        total = cashAmount - promoCashDiscount;
        // 应用优惠券
        if (selectedCoupons != null) {
          // 先应用满减券和无门槛券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '满减券' || coupon['type'] == '无门槛券') {
              total -= coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
            }
          }
          // 再应用折扣券
          for (final coupon in selectedCoupons) {
            if (coupon['type'] == '折扣券') {
              final discountRate = coupon['discount'] is num ? (coupon['discount'] as num).toDouble() : 1.0;
              total *= discountRate;
            }
          }
        }
        break;
      case PaymentMethod.shoppingCard:
        total = 0;
        break;
    }
    if (total < 0) total = 0;

    // 积分支付时，合计金额向上取整
    if (paymentMethod == PaymentMethod.points) {
      total = total.ceilToDouble();
    }

    return '合计：$unit${total.toStringAsFixed(paymentMethod == PaymentMethod.points ? 0 : 2)}';
  }

  /// 构建图标选择选项
  Widget _buildIconOption(IconData icon, IconData selectedIcon,
      Function setState, Function(IconData) onSelect) {
    final isSelected = icon == selectedIcon;
    return GestureDetector(
      onTap: () {
        setState(() {
          onSelect(icon);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF1A2C20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF13ec5b) : const Color(0xFF2A4532),
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// 显示管理分类对话框
  void _showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102216),
          title: const Text(
            '管理分类',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 分类列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ListTile(
                        leading: const Icon(Icons.category,
                            color: const Color(0xFF13ec5b)),
                        title: Text(category.name,
                            style: const TextStyle(color: Colors.white)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddEditCategoryDialog(category: category);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteCategoryConfirmationDialog(category);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 添加分类按钮
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddEditCategoryDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13ec5b),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('添加分类'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  /// 显示添加/编辑分类对话框
  void _showAddEditCategoryDialog({StarCategory? category}) {
    final _nameController = TextEditingController(text: category?.name ?? '');
    final _descriptionController =
        TextEditingController(text: category?.description ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF102216),
              title: Text(
                category != null ? '编辑分类' : '添加分类',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 名称输入
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: '分类名称',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A4532)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF13ec5b)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 描述输入
                      TextField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: '分类描述',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A4532)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF13ec5b)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 保存分类
                    final name = _nameController.text.trim();
                    final description = _descriptionController.text.trim();

                    if (name.isNotEmpty) {
                      final now = DateTime.now();

                      if (category != null) {
                        // 编辑现有分类
                        final updatedCategory = StarCategory(
                          id: category.id,
                          name: name,
                          description: description,
                          icon: category.icon,
                          sortOrder: category.sortOrder,
                          createdAt: category.createdAt,
                          updatedAt: now,
                        );

                        // 更新到数据库
                        final updatedCategoryId = updatedCategory.id;
                        if (updatedCategoryId != null) {
                          await _databaseService.updateCategory(
                              updatedCategoryId, updatedCategory.toMap());
                        }
                      } else {
                        // 添加新分类
                        final newCategory = StarCategory(
                          name: name,
                          description: description,
                          icon: 'local_offer', // 默认图标
                          sortOrder: _categories.length,
                          createdAt: now,
                          updatedAt: now,
                        );

                        // 插入到数据库
                        await _databaseService
                            .insertCategory(newCategory.toMap());
                      }

                      // 重新加载数据
                      await _loadData();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13ec5b),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建分类标签
  Widget _buildCategoryChip({
    required String name,
    required bool isSelected,
    required bool isAllFilter,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    // 使用StatefulBuilder为每个标签创建独立的状态
    return StatefulBuilder(
      builder: (context, setState) {
        bool showDelete = false;
        bool isBlinking = false;
        bool isBlinkState = false;

        // 启动闪烁动画
        void startBlinking() {
          setState(() {
            showDelete = true;
            isBlinking = true;
            isBlinkState = true;
          });

          // 持续闪烁效果
          void blink() {
            if (isBlinking) {
              setState(() {
                isBlinkState = !isBlinkState;
              });
              Future.delayed(const Duration(milliseconds: 300), blink);
            }
          }

          blink();
        }

        // 停止闪烁动画
        void stopBlinking() {
          setState(() {
            showDelete = false;
            isBlinking = false;
            isBlinkState = false;
          });
        }

        return GestureDetector(
          // 确保手势能够正确接收
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (showDelete) {
              // 如果已经显示删除按钮，点击则取消删除模式
              stopBlinking();
            } else {
              // 否则执行正常的点击逻辑
              onTap();
            }
          },
          onLongPress: isAllFilter
              ? null
              : () {
                  // 长按显示删除按钮并开始闪烁
                  startBlinking();
                },
          // 使用Stack包含标签和删除按钮
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 标签主体，使用AnimatedContainer实现闪烁效果
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? const Color(0xFF13ec5b)
                      : (isBlinkState
                          ? const Color(0xFF2A4532)
                          : const Color(0xFF1A2C20)),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF13ec5b)
                        : (isBlinkState
                            ? const Color(0xFF13ec5b)
                            : const Color(0xFF2A4532)),
                  ),
                  boxShadow: isSelected || isBlinkState
                      ? [
                          BoxShadow(
                            color: const Color(0xFF13ec5b).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              // 删除按钮
              if (showDelete && !isAllFilter)
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    // 阻止删除按钮的点击事件冒泡到父级
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      stopBlinking();
                      onDelete();
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 显示删除分类确认对话框
  void _showDeleteCategoryConfirmationDialog(StarCategory category) {
    // 检查是否有商品使用了该分类
    final hasProducts =
        _rewards.any((reward) => reward.categoryId == category.id);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102216),
          title: const Text(
            '确认删除',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            hasProducts ? '该分类下有商品，无法删除' : '确定要删除分类 "${category.name}" 吗？',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            if (!hasProducts)
              ElevatedButton(
                onPressed: () async {
                  // 删除分类
                  await _databaseService.deleteCategory(category.id!);
                  // 重新加载数据
                  await _loadData();
                  // 重置筛选索引，如果当前选中的是被删除的分类
                  if (_selectedFilterIndex > 0 &&
                      _selectedFilterIndex > _categories.length) {
                    setState(() {
                      _selectedFilterIndex = 0;
                    });
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
          ],
        );
      },
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmationDialog(StarProduct reward) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102216),
          title: const Text(
            '确认删除',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '确定要删除商品 "${reward.name}" 吗？',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                // 删除商品
                await _databaseService.deleteProduct(reward.id!);
                // 重新加载数据
                await _loadData();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  // 计算优惠金额
  int _calculateDiscountAmount(int cashAmount, int pointsAmount, Map<String, dynamic>? selectedCoupon, Map<String, dynamic>? selectedRedPacket, Map<String, dynamic>? selectedShoppingCard) {
    int discount = 0;
    
    // 优惠券优惠
    if (selectedCoupon != null) {
      if (selectedCoupon['type'] == '满减券') {
        discount += (selectedCoupon['amount'] is num ? (selectedCoupon['amount'] as num).toInt() : 0);
      } else if (selectedCoupon['type'] == '折扣券') {
        final discountRate = (selectedCoupon['discount'] is num ? (selectedCoupon['discount'] as num) : 1.0);
        discount += cashAmount - (cashAmount * discountRate).round();
      } else if (selectedCoupon['type'] == '无门槛券') {
        discount += (selectedCoupon['amount'] is num ? (selectedCoupon['amount'] as num).toInt() : 0);
      }
    }
    
    // 红包优惠
    if (selectedRedPacket != null) {
      discount += (selectedRedPacket['amount'] is num ? (selectedRedPacket['amount'] as num).toInt() : 0);
    }
    
    // 购物卡优惠
    if (selectedShoppingCard != null) {
      discount += cashAmount;
    }
    
    return discount;
  }

  // 计算合计金额
  int _calculateTotalAmount(int cashAmount, int pointsAmount, PaymentMethod paymentMethod, Map<String, dynamic>? selectedCoupon, Map<String, dynamic>? selectedRedPacket, Map<String, dynamic>? selectedShoppingCard) {
    int total = paymentMethod == PaymentMethod.points ? pointsAmount : cashAmount;
    
    // 应用优惠券
    if (selectedCoupon != null) {
      if (selectedCoupon['type'] == '满减券') {
        total -= (selectedCoupon['amount'] is num ? (selectedCoupon['amount'] as num).toInt() : 0);
      } else if (selectedCoupon['type'] == '折扣券') {
        final discountRate = (selectedCoupon['discount'] is num ? (selectedCoupon['discount'] as num).toDouble() : 1.0);
        if (paymentMethod == PaymentMethod.points) {
          // 积分支付：根据优惠金额上取整后计算合计
          double discountAmount = total.toDouble() * (1 - discountRate);
          int discountCeiled = discountAmount.ceil();
          total = total - discountCeiled;
        } else {
          // 现金支付：正常计算
          total = (total * discountRate).round();
        }
      } else if (selectedCoupon['type'] == '无门槛券') {
        total -= (selectedCoupon['amount'] is num ? (selectedCoupon['amount'] as num).toInt() : 0);
      }
    }
    
    // 应用红包
    if (selectedRedPacket != null) {
      total -= (selectedRedPacket['amount'] is num ? (selectedRedPacket['amount'] as num).toInt() : 0);
    }
    
    // 应用购物卡
    if (selectedShoppingCard != null) {
      total = 0;
    }
    
    return total > 0 ? total : 0;
  }


} 
