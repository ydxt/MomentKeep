import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/pages/add_product_step_by_step_page.dart';
import 'package:moment_keep/presentation/pages/cleanup_logs_page.dart';
import 'package:moment_keep/presentation/pages/cleanup_settings_page.dart';
import 'package:moment_keep/presentation/pages/merchant_product_preview_page.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/services/auto_cleanup_service.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 商家商品管理页面
class MerchantProductManagementPage extends ConsumerStatefulWidget {
  /// 构造函数
  const MerchantProductManagementPage({super.key});

  @override
  ConsumerState<MerchantProductManagementPage> createState() => _MerchantProductManagementPageState();
}

class _MerchantProductManagementPageState extends ConsumerState<MerchantProductManagementPage> {
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();
  
  /// 商品数据库服务实例
  final ProductDatabaseService _productDatabaseService = ProductDatabaseService();
  
  /// 主题数据
  late ThemeData theme;
  
  /// 分类列表数据
  List<StarCategory> _categories = [];
  
  /// 商品列表数据
  List<StarProduct> _products = [];
  
  /// 筛选后的商品列表
  List<StarProduct> _filteredProducts = [];
  
  /// 搜索关键字
  String _searchKeyword = '';
  
  /// 当前选中的状态
  String _selectedStatus = '全部';
  
  /// 当前视图模式：'list' 列表视图, 'category' 分类视图
  String _viewMode = 'list';
  
  /// 当前选中的分类ID
  int? _selectedCategoryId;
  
  /// 状态列表
  final List<String> _statusList = ['全部', '已上架', '已下架', '审核中', '已拒绝', '违规', '草稿', '审核通过'];
  
  /// 控制是否显示删除按钮
  bool _showDeleteButtons = false;
  
  /// 控制闪烁状态
  bool _blinkState = false;
  
  /// 闪烁定时器
  Timer? _blinkTimer;
  
  /// 开始闪烁效果
  void _startBlinking() {
    setState(() {
      _showDeleteButtons = true;
      _blinkState = true;
    });
    
    // 启动闪烁定时器
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _blinkState = !_blinkState;
      });
    });
  }
  
  /// 停止闪烁效果
  void _stopBlinking() {
    _blinkTimer?.cancel();
    setState(() {
      _showDeleteButtons = false;
      _blinkState = false;
    });
  }
  
  /// 显示添加/编辑分类对话框
  void _showAddEditCategoryDialog() {
    TextEditingController categoryNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: dialogTheme.colorScheme.surfaceVariant,
          title: Text('添加分类', style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
          content: TextField(
            controller: categoryNameController,
            style: TextStyle(color: dialogTheme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: '请输入分类名称',
              hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: dialogTheme.colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: dialogTheme.colorScheme.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('取消', style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              onPressed: () async {
                String categoryName = categoryNameController.text.trim();
                if (categoryName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分类名称不能为空'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // 创建新分类
                try {
                  // 准备分类数据
                  final categoryData = {
                    'name': categoryName,
                    'description': '',
                    'icon': '',
                    'sort_order': 0,
                    'created_at': DateTime.now().millisecondsSinceEpoch,
                    'updated_at': DateTime.now().millisecondsSinceEpoch
                  };
                  
                  // 保存到数据库
                  final categoryId = await _productDatabaseService.insertCategory(categoryData);
                  
                  // 创建StarCategory对象
                  StarCategory newCategory = StarCategory(
                    id: categoryId,
                    name: categoryName,
                    description: '',
                    icon: '',
                    sortOrder: 0,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  
                  // 更新UI
                  setState(() {
                    _categories.add(newCategory);
                  });
                  
                  // 关闭对话框
                  Navigator.pop(context);
                  
                  // 显示成功消息
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分类添加成功'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('添加分类失败: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('确定'),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.primary,
              foregroundColor: dialogTheme.colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// 显示删除分类确认对话框
  void _showDeleteCategoryConfirmationDialog(StarCategory category) {
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = ref.watch(currentThemeProvider);
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除分类 "${category.name}" 吗？'),
          backgroundColor: dialogTheme.colorScheme.surfaceVariant,
          titleTextStyle: TextStyle(color: dialogTheme.colorScheme.onSurface),
          contentTextStyle: TextStyle(color: dialogTheme.colorScheme.onSurface),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('取消', style: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                // 实现删除分类的逻辑
                Navigator.pop(context);
                try {
                  // 从本地列表中移除分类
                  setState(() {
                    _categories.remove(category);
                  });
                  // 如果删除的是当前选中的分类，重置选中状态
                  if (_selectedCategoryId == category.id) {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                    _applyFilters();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分类删除成功'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除分类失败: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                _stopBlinking();
              },
              child: Text('删除', style: TextStyle(color: dialogTheme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }
  
  /// 是否显示高级筛选弹窗
  bool _showFilterDialog = false;
  
  /// 高级筛选条件
  Map<String, dynamic> _advancedFilters = {
    'selectedCategoryIds': <int>[], // 选中的分类ID列表
    'priceRange': {'min': null, 'max': null}, // 价格范围
    'stockFilter': 'all', // 库存筛选：all, low, sufficient
    'salesFilter': null, // 销量筛选
    'preSaleFilter': null, // 预售筛选
    'activityFilter': null, // 活动筛选
    'shippingTemplateFilter': null, // 运费模板筛选
    'releaseTimeFilter': null, // 上架时间筛选：7days, 30days, custom
    'customReleaseTime': {'start': null, 'end': null}, // 自定义上架时间范围
  };
  
  /// 批量操作相关
  Set<int> _selectedProductIds = {}; // 选中的商品ID集合
  bool _isSelectAll = false; // 是否全选
  
  /// 分页相关
  int _currentPage = 1;
  int _pageSize = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  
  /// 滚动控制器，用于检测滚动到底部
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    // 初始化数据
    _loadData();
    
    // 添加滚动监听器
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // 清理滚动控制器
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 从数据库加载数据
  Future<void> _loadData() async {
    try {
      // 加载分类数据
      final categoriesMaps = await _productDatabaseService.getAllCategories();
      final categories = categoriesMaps.map((map) => StarCategory.fromMap(map)).toList();
      
      // 加载商品数据
      final products = await _databaseService.getAllStarProducts();
      
      setState(() {
        _categories = categories;
        _products = products;
        _filteredProducts = products;
      });
      
      _applyFilters();
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }
  }
  
  /// 计算每种状态的商品数量
  int _calculateStatusCount(String status) {
    if (status == '全部') {
      return _products.length;
    }
    
    switch (status) {
      case '已上架':
        return _products.where((product) => product.status == 'active').length;
      case '已下架':
        return _products.where((product) => product.status == 'inactive').length;
      case '审核中':
        return _products.where((product) => product.status == 'pending').length;
      case '已拒绝':
        return _products.where((product) => product.status == 'rejected').length;
      case '违规':
        return _products.where((product) => product.status == 'violated').length;
      case '草稿':
        return _products.where((product) => product.status == 'draft').length;
      case '审核通过':
        return _products.where((product) => product.status == 'approved').length;
      default:
        return 0;
    }
  }
  
  /// 应用筛选条件
  void _applyFilters() {
    setState(() {
      // 首先获取所有匹配的商品
      final allFilteredProducts = _products.where((product) {
        // 搜索筛选
        final matchesSearch = _searchKeyword.isEmpty || 
            product.name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            product.id.toString().contains(_searchKeyword) ||
            product.productCode.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            (product.tags.any((tag) => tag.toLowerCase().contains(_searchKeyword.toLowerCase()))) ||
            (product.skus?.any((sku) => sku.skuCode.toLowerCase().contains(_searchKeyword.toLowerCase())) ?? false);
        
        // 状态筛选
        bool matchesStatus = true;
        // 当选中'全部'时，不进行状态筛选
        if (_selectedStatus != '全部') {
          switch (_selectedStatus) {
            case '已上架':
              matchesStatus = product.status == 'active';
              break;
            case '已下架':
              matchesStatus = product.status == 'inactive';
              break;
            case '审核中':
              matchesStatus = product.status == 'pending';
              break;
            case '已拒绝':
              matchesStatus = product.status == 'rejected';
              break;
            case '违规':
              matchesStatus = product.status == 'violated';
              break;
            case '草稿':
              matchesStatus = product.status == 'draft';
              break;
            case '审核通过':
              matchesStatus = product.status == 'approved';
              break;
          }
        }
        
        // 分类筛选
        bool matchesCategory = true;
        if (_selectedCategoryId != null) {
          matchesCategory = product.categoryId == _selectedCategoryId;
        } else if (_advancedFilters['selectedCategoryIds'].isNotEmpty) {
          matchesCategory = _advancedFilters['selectedCategoryIds'].contains(product.categoryId);
        }
        
        // 价格范围筛选
        bool matchesPrice = true;
        final priceRange = _advancedFilters['priceRange'];
        if (priceRange['min'] != null && product.points < priceRange['min']) {
          matchesPrice = false;
        }
        if (priceRange['max'] != null && product.points > priceRange['max']) {
          matchesPrice = false;
        }
        
        // 库存筛选
        bool matchesStock = true;
        final stockFilter = _advancedFilters['stockFilter'];
        switch (stockFilter) {
          case 'low':
            matchesStock = product.stock > 0 && product.stock < 10;
            break;
          case 'sufficient':
            matchesStock = product.stock >= 10;
            break;
          case 'empty':
            matchesStock = product.stock == 0;
            break;
        }
        
        // 销量筛选
        bool matchesSales = true;
        final salesFilter = _advancedFilters['salesFilter'];
        if (salesFilter != null) {
          switch (salesFilter) {
            case 'sales7Days':
              matchesSales = product.sales7Days > 0;
              break;
            case 'totalSales':
              matchesSales = product.totalSales > 0;
              break;
          }
        }
        
        // 预售筛选
        bool matchesPreSale = true;
        final preSaleFilter = _advancedFilters['preSaleFilter'];
        if (preSaleFilter != null) {
          matchesPreSale = product.isPreSale == preSaleFilter;
        }
        
        // 活动筛选
        bool matchesActivity = true;
        final activityFilter = _advancedFilters['activityFilter'];
        if (activityFilter != null && activityFilter.isNotEmpty) {
          matchesActivity = product.tags.any((tag) => activityFilter.contains(tag));
        }
        
        // 运费模板筛选
        bool matchesShippingTemplate = true;
        final shippingTemplateFilter = _advancedFilters['shippingTemplateFilter'];
        if (shippingTemplateFilter != null) {
          matchesShippingTemplate = product.shippingTemplateId == shippingTemplateFilter;
        }
        
        // 上架时间筛选
        bool matchesReleaseTime = true;
        final releaseTimeFilter = _advancedFilters['releaseTimeFilter'];
        if (releaseTimeFilter != null) {
          final now = DateTime.now();
          DateTime startDate;
          
          switch (releaseTimeFilter) {
            case '7days':
              startDate = now.subtract(const Duration(days: 7));
              matchesReleaseTime = product.releaseTime != null && product.releaseTime!.isAfter(startDate);
              break;
            case '30days':
              startDate = now.subtract(const Duration(days: 30));
              matchesReleaseTime = product.releaseTime != null && product.releaseTime!.isAfter(startDate);
              break;
            case 'custom':
              final customReleaseTime = _advancedFilters['customReleaseTime'];
              final customStart = customReleaseTime['start'];
              final customEnd = customReleaseTime['end'];
              
              if (customStart != null && product.releaseTime != null) {
                matchesReleaseTime = product.releaseTime!.isAfter(customStart);
              }
              if (customEnd != null && product.releaseTime != null) {
                matchesReleaseTime = matchesReleaseTime && product.releaseTime!.isBefore(customEnd);
              }
              break;
          }
        }
        
        return matchesSearch && matchesStatus && matchesCategory && matchesPrice && matchesStock && 
               matchesSales && matchesPreSale && matchesActivity && matchesShippingTemplate && matchesReleaseTime;
      }).toList();
      
      // 应用分页
      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;
      
      if (startIndex >= allFilteredProducts.length) {
        // 如果起始索引超出范围，显示空列表
        _filteredProducts = [];
        _hasMoreData = false;
      } else {
        // 截取当前页的数据
        _filteredProducts = allFilteredProducts.sublist(
          startIndex,
          endIndex > allFilteredProducts.length ? allFilteredProducts.length : endIndex,
        );
        
        // 判断是否还有更多数据
        _hasMoreData = endIndex < allFilteredProducts.length;
      }
    });
  }
  
  /// 检测滚动到底部
  void _onScroll() {
    if (_isLoadingMore || !_hasMoreData) return;
    
    final scrollPosition = _scrollController.position;
    if (scrollPosition.pixels >= scrollPosition.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }
  
  /// 加载更多数据
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // 增加当前页码
      _currentPage++;
      // 重新应用筛选条件，获取新一页的数据
      _applyFilters();
    } catch (e) {
      debugPrint('加载更多数据失败: $e');
      // 如果失败，恢复原来的页码
      _currentPage--;
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  /// 商品状态流转处理
  Future<void> _handleProductStatusTransition(StarProduct product, String newStatus) async {
    try {
      // 正常提交审核流程，不再直接设置为审核通过
      // if (product.status == 'draft' && newStatus == 'pending') {
      //   newStatus = 'approved';
      // }
      
      // 验证状态流转是否合法
      if (!_isValidStatusTransition(product.status, newStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无效的状态流转'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 处理特定状态流转的附加逻辑
      final updatedProduct = StarProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        image: product.image,
        mainImages: product.mainImages,
        productCode: product.productCode,
        points: product.points,
        hybridPoints: product.hybridPoints,
        hybridPrice: product.hybridPrice,
        costPrice: product.costPrice,
        stock: product.stock,
        categoryId: product.categoryId,
        brand: product.brand,
        tags: product.tags,
        categoryPath: product.categoryPath,
        isActive: newStatus == 'active',
        isDeleted: product.isDeleted,
        status: newStatus,
        shippingTemplateId: product.shippingTemplateId,
        isPreSale: product.isPreSale,
        preSaleEndTime: product.preSaleEndTime,
        releaseTime: newStatus == 'active' ? DateTime.now() : product.releaseTime,
        scheduledReleaseTime: product.scheduledReleaseTime,
        sales7Days: product.sales7Days,
        totalSales: product.totalSales,
        visitors: product.visitors,
        conversionRate: product.conversionRate,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: product.deletedAt,
        skus: product.skus ?? [],
        specs: product.specs ?? [],
        video: product.video,
        videoCover: product.videoCover,
        videoDescription: product.videoDescription,
        detailImages: product.detailImages,
        detail: product.detail,
        weight: product.weight,
        volume: product.volume,
        originalPrice: product.originalPrice,
        price: product.price,
        memberPrice: product.memberPrice,
        shippingTime: product.shippingTime,
        shippingAddress: product.shippingAddress,
        returnPolicy: product.returnPolicy,
        sortWeight: product.sortWeight,
        isLimitedPurchase: product.isLimitedPurchase,
        limitQuantity: product.limitQuantity,
        internalNote: product.internalNote,
        seoTitle: product.seoTitle,
        seoKeywords: product.seoKeywords,
        // 支付方式相关字段
        supportPointsPayment: product.supportPointsPayment,
        supportCashPayment: product.supportCashPayment,
        supportHybridPayment: product.supportHybridPayment,
      );
      
      await _databaseService.updateStarProduct(updatedProduct);
      await _loadData();
      
      // 显示操作结果
      String message = _getStatusTransitionMessage(product.status, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('切换商品状态失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作失败，请重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// 验证状态流转是否合法
  bool _isValidStatusTransition(String currentStatus, String newStatus) {
    // 定义合法的状态流转映射
    final validTransitions = {
      'draft': ['pending', 'deleted'],
      'pending': ['approved', 'rejected', 'draft'],
      'approved': ['active', 'draft', 'deleted'],
      'active': ['inactive'],
      'inactive': ['active', 'draft', 'deleted'],
      'rejected': ['draft'],
      'violated': ['draft'],
      'deleted': ['draft']
    };
    
    return validTransitions[currentStatus]?.contains(newStatus) ?? false;
  }
  
  /// 获取状态流转消息
  String _getStatusTransitionMessage(String fromStatus, String toStatus) {
    final messageMap = {
      'draft_to_pending': '商品已提交审核',
      'pending_to_approved': '商品审核通过',
      'pending_to_rejected': '商品审核驳回',
      'approved_to_active': '商品已上架',
      'active_to_inactive': '商品已下架',
      'inactive_to_active': '商品已重新上架',
      'rejected_to_draft': '商品已转为草稿',
      'violated_to_draft': '商品已转为草稿，可重新编辑提交',
      'approved_to_draft': '商品已转为草稿',
      'inactive_to_draft': '商品已转为草稿'
    };
    
    return messageMap['${fromStatus}_to_$toStatus'] ?? '商品状态已更新';
  }
  
  /// 批量修改商品状态
  Future<void> _batchChangeStatus(String newStatus) async {
    try {
      final productsToUpdate = _products.where((product) => _selectedProductIds.contains(product.id)).toList();
      
      for (final product in productsToUpdate) {
        if (_isValidStatusTransition(product.status, newStatus)) {
          final updatedProduct = StarProduct(
            id: product.id,
            name: product.name,
            description: product.description,
            image: product.image,
            mainImages: product.mainImages,
            productCode: product.productCode,
            points: product.points,
            hybridPoints: product.hybridPoints,
            hybridPrice: product.hybridPrice,
            costPrice: product.costPrice,
            stock: product.stock,
            categoryId: product.categoryId,
            brand: product.brand,
            tags: product.tags,
            categoryPath: product.categoryPath,
            isActive: newStatus == 'active',
            isDeleted: product.isDeleted,
            status: newStatus,
            shippingTemplateId: product.shippingTemplateId,
            isPreSale: product.isPreSale,
            preSaleEndTime: product.preSaleEndTime,
            releaseTime: newStatus == 'active' ? DateTime.now() : product.releaseTime,
            scheduledReleaseTime: product.scheduledReleaseTime,
            sales7Days: product.sales7Days,
            totalSales: product.totalSales,
            visitors: product.visitors,
            conversionRate: product.conversionRate,
            createdAt: product.createdAt,
            updatedAt: DateTime.now(),
            deletedAt: product.deletedAt,
            skus: product.skus ?? [],
            specs: product.specs ?? [],
            video: product.video,
            videoCover: product.videoCover,
            videoDescription: product.videoDescription,
            detailImages: product.detailImages,
            detail: product.detail,
            weight: product.weight,
            volume: product.volume,
            originalPrice: product.originalPrice,
            price: product.price,
            memberPrice: product.memberPrice,
            shippingTime: product.shippingTime,
            shippingAddress: product.shippingAddress,
            returnPolicy: product.returnPolicy,
            sortWeight: product.sortWeight,
            isLimitedPurchase: product.isLimitedPurchase,
            limitQuantity: product.limitQuantity,
            internalNote: product.internalNote,
            seoTitle: product.seoTitle,
            seoKeywords: product.seoKeywords,
            // 支付方式相关字段
            supportPointsPayment: product.supportPointsPayment,
            supportCashPayment: product.supportCashPayment,
            supportHybridPayment: product.supportHybridPayment,
          );
          await _databaseService.updateStarProduct(updatedProduct);
        }
      }
      
      await _loadData();
      setState(() {
        _selectedProductIds.clear();
        _isSelectAll = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('批量${newStatus == 'active' ? '上架' : '下架'}成功'),
          backgroundColor: const Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('批量修改状态失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作失败，请重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// 批量删除商品
  Future<void> _batchDelete() async {
    try {
      final productsToDelete = _products.where((product) => _selectedProductIds.contains(product.id)).toList();
      
      for (final product in productsToDelete) {
        if (_isValidStatusTransition(product.status, 'deleted')) {
          final updatedProduct = StarProduct(
            id: product.id,
            name: product.name,
            description: product.description,
            image: product.image,
            mainImages: product.mainImages,
            productCode: product.productCode,
            points: product.points,
            hybridPoints: product.hybridPoints,
            hybridPrice: product.hybridPrice,
            costPrice: product.costPrice,
            stock: product.stock,
            categoryId: product.categoryId,
            brand: product.brand,
            tags: product.tags,
            categoryPath: product.categoryPath,
            isActive: product.isActive,
            isDeleted: true,
            status: product.status,
            shippingTemplateId: product.shippingTemplateId,
            isPreSale: product.isPreSale,
            preSaleEndTime: product.preSaleEndTime,
            releaseTime: product.releaseTime,
            scheduledReleaseTime: product.scheduledReleaseTime,
            sales7Days: product.sales7Days,
            totalSales: product.totalSales,
            visitors: product.visitors,
            conversionRate: product.conversionRate,
            createdAt: product.createdAt,
            updatedAt: DateTime.now(),
            deletedAt: DateTime.now(),
            skus: product.skus ?? [],
            specs: product.specs ?? [],
            video: product.video,
            videoCover: product.videoCover,
            videoDescription: product.videoDescription,
            detailImages: product.detailImages,
            detail: product.detail,
            weight: product.weight,
            volume: product.volume,
            originalPrice: product.originalPrice,
            price: product.price,
            memberPrice: product.memberPrice,
            shippingTime: product.shippingTime,
            shippingAddress: product.shippingAddress,
            returnPolicy: product.returnPolicy,
            sortWeight: product.sortWeight,
            isLimitedPurchase: product.isLimitedPurchase,
            limitQuantity: product.limitQuantity,
            internalNote: product.internalNote,
            seoTitle: product.seoTitle,
            seoKeywords: product.seoKeywords,
            // 支付方式相关字段
            supportPointsPayment: product.supportPointsPayment,
            supportCashPayment: product.supportCashPayment,
            supportHybridPayment: product.supportHybridPayment,
          );
          await _databaseService.updateStarProduct(updatedProduct);
        }
      }
      
      await _loadData();
      setState(() {
        _selectedProductIds.clear();
        _isSelectAll = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('批量删除成功'),
          backgroundColor: const Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('批量删除失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('操作失败，请重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// 批量修改价格
  void _batchChangePrice() {
    // 实现批量修改价格功能
    TextEditingController priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return Dialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '批量修改价格',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: priceController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '请输入新价格',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        String priceText = priceController.text.trim();
                        if (priceText.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }
                        int newPrice = int.parse(priceText);
                        Navigator.pop(context);
                        
                        // 执行批量修改价格
                        try {
                          final productsToUpdate = _products.where((product) => _selectedProductIds.contains(product.id)).toList();
                          
                          for (final product in productsToUpdate) {
                            final updatedProduct = StarProduct(
                              id: product.id,
                              name: product.name,
                              description: product.description,
                              image: product.image,
                              productCode: product.productCode,
                              points: newPrice,
                              costPrice: product.costPrice,
                              stock: product.stock,
                              categoryId: product.categoryId,
                              brand: product.brand,
                              tags: product.tags,
                              categoryPath: product.categoryPath,
                              isActive: product.isActive,
                              isDeleted: product.isDeleted,
                              status: product.status,
                              shippingTemplateId: product.shippingTemplateId,
                              isPreSale: product.isPreSale,
                              preSaleEndTime: product.preSaleEndTime,
                              releaseTime: product.releaseTime,
                              scheduledReleaseTime: product.scheduledReleaseTime,
                              sales7Days: product.sales7Days,
                              totalSales: product.totalSales,
                              visitors: product.visitors,
                              conversionRate: product.conversionRate,
                              createdAt: product.createdAt,
                              updatedAt: DateTime.now(),
                              deletedAt: product.deletedAt,
                            );
                            await _databaseService.updateStarProduct(updatedProduct);
                          }
                          
                          await _loadData();
                          setState(() {
                            _selectedProductIds.clear();
                            _isSelectAll = false;
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('批量修改价格成功，共修改 ${productsToUpdate.length} 个商品'),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        } catch (e) {
                          debugPrint('批量修改价格失败: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('操作失败，请重试'),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      },
                      child: const Text('确定'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// 批量修改库存
  void _batchChangeStock() {
    // 实现批量修改库存功能
    TextEditingController stockController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return Dialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '批量修改库存',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: stockController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '请输入新库存',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        String stockText = stockController.text.trim();
                        if (stockText.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }
                        int newStock = int.parse(stockText);
                        Navigator.pop(context);
                        
                        // 执行批量修改库存
                        try {
                          final productsToUpdate = _products.where((product) => _selectedProductIds.contains(product.id)).toList();
                          
                          for (final product in productsToUpdate) {
                            final updatedProduct = StarProduct(
                              id: product.id,
                              name: product.name,
                              description: product.description,
                              image: product.image,
                              productCode: product.productCode,
                              points: product.points,
                              costPrice: product.costPrice,
                              stock: newStock,
                              categoryId: product.categoryId,
                              brand: product.brand,
                              tags: product.tags,
                              categoryPath: product.categoryPath,
                              isActive: product.isActive,
                              isDeleted: product.isDeleted,
                              status: product.status,
                              shippingTemplateId: product.shippingTemplateId,
                              isPreSale: product.isPreSale,
                              preSaleEndTime: product.preSaleEndTime,
                              releaseTime: product.releaseTime,
                              scheduledReleaseTime: product.scheduledReleaseTime,
                              sales7Days: product.sales7Days,
                              totalSales: product.totalSales,
                              visitors: product.visitors,
                              conversionRate: product.conversionRate,
                              createdAt: product.createdAt,
                              updatedAt: DateTime.now(),
                              deletedAt: product.deletedAt,
                            );
                            await _databaseService.updateStarProduct(updatedProduct);
                          }
                          
                          await _loadData();
                          setState(() {
                            _selectedProductIds.clear();
                            _isSelectAll = false;
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('批量修改库存成功，共修改 ${productsToUpdate.length} 个商品'),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        } catch (e) {
                          debugPrint('批量修改库存失败: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('操作失败，请重试'),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      },
                      child: const Text('确定'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// 批量导出商品
  void _batchExport() {
    // 实现批量导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('批量导出功能开发中'),
        backgroundColor: const Color(0xFF13ec5b),
      ),
    );
  }
  
  /// 手动清理过期商品
  Future<void> _manualCleanup() async {
    try {
      // 显示确认对话框
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          final theme = ref.watch(currentThemeProvider);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surfaceVariant,
            title: Text('确认清理', style: TextStyle(color: theme.colorScheme.onSurface)),
            content: Text('确定要手动清理过期商品吗？此操作将删除30天前标记为删除的商品及其相关文件。', style: TextStyle(color: theme.colorScheme.onSurface)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface)),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('确定', style: TextStyle(color: theme.colorScheme.onPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          );
        },
      );
      
      if (confirm != true) return;
      
      // 显示加载指示器
      final theme = ref.watch(currentThemeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('正在清理过期商品...'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
      
      // 调用自动清理服务进行手动清理
      final autoCleanupService = AutoCleanupService();
      await autoCleanupService.cleanupExpiredProducts();
      
      // 清理完成后重新加载数据
      await _loadData();
      
      // 显示清理完成提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('过期商品清理完成'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    } catch (e) {
      debugPrint('手动清理失败: $e');
      final theme = ref.watch(currentThemeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('清理失败，请重试'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }
  
  /// 显示添加/编辑商品页面
  void _showAddEditProductPage({StarProduct? product}) {
    // 如果是新增商品，先清除之前的草稿
    if (product == null) {
      _clearDraft();
    }
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => AddProductStepByStepPage(
          product: product,
          onSubmit: _loadData,
        ),
      ),
    );
  }
  
  /// 清除草稿
  void _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('add_product_draft');
  }
  
  /// 显示高级筛选对话框
  void _showAdvancedFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 对话框标题
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '高级筛选',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    
                    // 筛选内容
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 分类筛选
                            Text(
                              '分类',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((category) {
                                return FilterChip(
                                  label: Text(category.name),
                                  labelStyle: TextStyle(
                                    color: _advancedFilters['selectedCategoryIds'].contains(category.id)
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  backgroundColor: theme.colorScheme.surface,
                                  selectedColor: theme.colorScheme.primary,
                                  showCheckmark: false,
                                  selected: _advancedFilters['selectedCategoryIds'].contains(category.id),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _advancedFilters['selectedCategoryIds'].add(category.id!);
                                      } else {
                                        _advancedFilters['selectedCategoryIds'].remove(category.id!);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            
                            // 价格范围
                            Text(
                              '价格范围',
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
                                  child: TextField(
                                    style: TextStyle(color: theme.colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      hintText: '最小值',
                                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: theme.colorScheme.primary),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _advancedFilters['priceRange']['min'] = value.isEmpty ? null : int.tryParse(value);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '-',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    style: TextStyle(color: theme.colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      hintText: '最大值',
                                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: theme.colorScheme.primary),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      filled: true,
                                      fillColor: theme.colorScheme.surface,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _advancedFilters['priceRange']['max'] = value.isEmpty ? null : int.tryParse(value);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // 库存筛选
                            Text(
                              '库存',
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
                                  child: RadioListTile<String>(
                                  title: Text('全部', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: 'all',
                                  groupValue: _advancedFilters['stockFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['stockFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                  title: Text('库存不足(<10)', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: 'low',
                                  groupValue: _advancedFilters['stockFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['stockFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                  title: Text('库存充足(≥10)', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: 'sufficient',
                                  groupValue: _advancedFilters['stockFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['stockFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                  title: Text('无库存', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: 'empty',
                                  groupValue: _advancedFilters['stockFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['stockFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // 销量筛选
                            Text(
                              '销量',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: Text('近7天有销量'),
                                  labelStyle: TextStyle(
                                    color: _advancedFilters['salesFilter'] == 'sales7Days'
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  backgroundColor: theme.colorScheme.surface,
                                  selectedColor: theme.colorScheme.primary,
                                  showCheckmark: false,
                                  selected: _advancedFilters['salesFilter'] == 'sales7Days',
                                  onSelected: (selected) {
                                    setState(() {
                                      _advancedFilters['salesFilter'] = selected ? 'sales7Days' : null;
                                    });
                                  },
                                ),
                                FilterChip(
                                  label: Text('累计有销量'),
                                  labelStyle: TextStyle(
                                    color: _advancedFilters['salesFilter'] == 'totalSales'
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  backgroundColor: theme.colorScheme.surface,
                                  selectedColor: theme.colorScheme.primary,
                                  showCheckmark: false,
                                  selected: _advancedFilters['salesFilter'] == 'totalSales',
                                  onSelected: (selected) {
                                    setState(() {
                                      _advancedFilters['salesFilter'] = selected ? 'totalSales' : null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // 预售筛选
                            Text(
                              '预售',
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
                                  child: RadioListTile<bool?>(
                                  title: Text('全部', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: null,
                                  groupValue: _advancedFilters['preSaleFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['preSaleFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                                Expanded(
                                  child: RadioListTile<bool?>(
                                  title: Text('预售商品', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: true,
                                  groupValue: _advancedFilters['preSaleFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['preSaleFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // 上架时间筛选
                            Text(
                              '上架时间',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                RadioListTile<String?>(
                                  title: Text('全部', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: null,
                                  groupValue: _advancedFilters['releaseTimeFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['releaseTimeFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                RadioListTile<String?>(
                                  title: Text('近7天', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: '7days',
                                  groupValue: _advancedFilters['releaseTimeFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['releaseTimeFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                RadioListTile<String?>(
                                  title: Text('近30天', style: TextStyle(color: theme.colorScheme.onSurface)),
                                  value: '30days',
                                  groupValue: _advancedFilters['releaseTimeFilter'],
                                  onChanged: (value) {
                                    setState(() {
                                      _advancedFilters['releaseTimeFilter'] = value;
                                    });
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  tileColor: theme.colorScheme.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 操作按钮
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // 重置筛选条件
                                setState(() {
                                  _advancedFilters = {
                                    'selectedCategoryIds': <int>[],
                                    'priceRange': {'min': null, 'max': null},
                                    'stockFilter': 'all',
                                    'salesFilter': null,
                                    'preSaleFilter': null,
                                    'activityFilter': null,
                                    'shippingTemplateFilter': null,
                                    'releaseTimeFilter': null,
                                    'customReleaseTime': {'start': null, 'end': null},
                                  };
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface,
                                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: Text('重置', style: TextStyle(color: theme.colorScheme.onSurface)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // 应用筛选条件
                                Navigator.pop(context);
                                _applyFilters();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: Text('确定', style: TextStyle(color: theme.colorScheme.onPrimary)),
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
      });
  }
  
  /// 构建商品卡片
  Widget _buildProductCard(StarProduct product, ThemeData theme) {
    // 确定商品状态
    String statusText = '已下架';
    Color statusColor = const Color(0xFF2A4532);
    bool isActive = false;
    
    switch (product.status) {
      case 'active':
        statusText = '已上架';
        statusColor = const Color(0xFF13ec5b);
        isActive = true;
        break;
      case 'inactive':
        statusText = '已下架';
        statusColor = const Color(0xFF2A4532);
        break;
      case 'pending':
        statusText = '审核中';
        statusColor = Colors.yellow;
        break;
      case 'approved':
        statusText = '审核通过';
        statusColor = const Color(0xFF13ec5b);
        break;
      case 'rejected':
        statusText = '审核驳回';
        statusColor = Colors.red;
        break;
      case 'violated':
        statusText = '违规下架';
        statusColor = Colors.red;
        break;
      case 'draft':
        statusText = '草稿';
        statusColor = Colors.grey;
        break;
    }
    
    return GestureDetector(
      onTap: () {
        // 商品预览功能 - 跳转到商品预览页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MerchantProductPreviewPage(product: product),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择框
            Checkbox(
              value: _selectedProductIds.contains(product.id),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedProductIds.add(product.id!);
                  } else {
                    _selectedProductIds.remove(product.id);
                  }
                });
              },
              activeColor: theme.colorScheme.primary,
              checkColor: theme.colorScheme.onPrimary,
            ),
            
            // 商品图片
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: ImageLoaderService.getImageProvider(product.image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // 商品信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品名称和状态
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // 商品编码
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '商品编码: ${product.productCode}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    
                    // 分类和品牌
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (product.categoryPath != null) 
                            Text(
                              '分类: ${product.categoryPath}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          if (product.brand != null) 
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                '品牌: ${product.brand}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // 价格和库存
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 价格
                          Row(
                            children: [
                              Text(
                                '${product.points} 积分',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (product.costPrice > 0) 
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '成本: ${product.costPrice} 积分',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          // 库存
                          Text(
                            '库存: ${product.stock}',
                            style: TextStyle(
                              color: product.stock < 10 ? theme.colorScheme.error : theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 数据指标
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '近7天销量: ${product.sales7Days}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '累计销量: ${product.totalSales}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '访客数: ${product.visitors}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '转化率: ${(product.conversionRate * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 操作按钮
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 审核通过后可上架
                          if (product.status == 'approved') 
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () => _handleProductStatusTransition(product, 'active'),
                                child: const Text(
                                  '上架',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                            ),
                          
                          // 草稿状态可提交审核
                          if (product.status == 'draft') 
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () => _handleProductStatusTransition(product, 'pending'),
                                child: const Text(
                                  '提交审核',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                            ),
                          
                          // 删除按钮
                          IconButton(
                            onPressed: () => _handleProductStatusTransition(product, 'deleted'),
                            icon: Icon(Icons.delete, color: theme.colorScheme.error, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          
                          // 违规商品显示整改按钮
                          if (product.status == 'violated') 
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  _showAddEditProductPage(product: product);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: const Text(
                                  '立即整改',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          
                          // 编辑按钮
                          if (product.status != 'pending') // 审核中不能编辑
                            IconButton(
                              onPressed: () => _showAddEditProductPage(product: product),
                              icon: Icon(Icons.edit, color: theme.colorScheme.onSurfaceVariant, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          
                          // 上下架按钮
                          if (product.status == 'active' || product.status == 'inactive') 
                            IconButton(
                              onPressed: () => _handleProductStatusTransition(
                                product,
                                product.status == 'active' ? 'inactive' : 'active'
                              ),
                              icon: Icon(
                                product.status == 'active' ? Icons.visibility : Icons.visibility_off,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16, right: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  // 标题和新增按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '商品管理',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // 右侧按钮区域
                      Row(
                        children: [
                          // 清理相关按钮 - 只有管理员可见
                          BlocBuilder<SecurityBloc, SecurityState>(
                            builder: (context, securityState) {
                              bool isAdmin = false;
                              if (securityState is SecurityLoaded) {
                                isAdmin = securityState.userAuth.isAdmin;
                              }
                              
                              if (isAdmin) {
                                return Row(
                                  children: [
                                    // 清理日志按钮
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const CleanupLogsPage(),
                                          ),
                                        );
                                      },
                                      icon: Icon(Icons.history, size: 20, color: theme.colorScheme.onPrimary),
                                      label: Text(
                                        '清理日志',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 清理设置按钮
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const CleanupSettingsPage(),
                                          ),
                                        );
                                      },
                                      icon: Icon(Icons.settings, size: 20, color: theme.colorScheme.onSecondary),
                                      label: Text(
                                        '清理设置',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.secondary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 手动清理按钮
                                    ElevatedButton.icon(
                                      onPressed: _manualCleanup,
                                      icon: Icon(Icons.cleaning_services, size: 20, color: theme.colorScheme.onTertiary),
                                      label: Text(
                                        '清理商品',
                                        style: TextStyle(
                                          color: theme.colorScheme.onTertiary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.tertiary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                          // 新增商品按钮 - 所有用户可见
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditProductPage(),
                            icon: Icon(Icons.add, size: 20, color: theme.colorScheme.onPrimary),
                            label: Text(
                              '新增商品',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // 状态筛选标签
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 全部标签
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = '全部';
                            });
                            _applyFilters();
                          },
                          icon: const SizedBox(),
                          label: Row(
                            children: [
                              Text(
                                '全部',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                color: theme.colorScheme.onPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                                child: Text(
                                '${_calculateStatusCount('全部')}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        
                        // 其他状态标签
                        const SizedBox(width: 8),
                        for (final status in _statusList.where((s) => s != '全部'))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = status;
                                });
                                _applyFilters();
                              },
                              icon: const SizedBox(),
                              label: Row(
                                children: [
                                  Text(
                                    status,
                                    style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_calculateStatusCount(status)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // 搜索和筛选栏
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // 搜索框
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
                          ),
                          child: TextField(
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            onChanged: (value) {
                              setState(() {
                                _searchKeyword = value;
                              });
                              _applyFilters();
                            },
                            decoration: InputDecoration(
                              hintText: '商品名称 / 编码 / SKU',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 高级筛选按钮
                      ElevatedButton.icon(
                        onPressed: _showAdvancedFilterDialog,
                        icon: Icon(Icons.filter_alt, size: 18, color: theme.colorScheme.onSurface),
                        label: Text(
                          '筛选',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 分类筛选
            GestureDetector(
              // 点击任何位置停止闪烁
              onTap: _stopBlinking,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
                ),
                height: 72, // 固定高度，确保ReorderableListView有明确的高度约束
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategoryId == category.id;
                  
                  return Padding(
                    key: ValueKey(category.id),
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      // 阻止事件冒泡，避免触发外部的_stopBlinking
                      onTap: () {
                        if (_showDeleteButtons) {
                          _stopBlinking();
                        } else {
                          setState(() {
                            _selectedCategoryId = category.id;
                          });
                          _applyFilters();
                        }
                      },
                      onLongPress: () {
                        _startBlinking();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 36, // 统一高度，与"全部分类"按钮匹配
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary
                              : (_showDeleteButtons 
                                  ? (_blinkState ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.surfaceVariant)
                                  : theme.colorScheme.surfaceVariant),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected 
                                ? theme.colorScheme.primary
                                : (_showDeleteButtons 
                                    ? (_blinkState ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3))
                                    : theme.colorScheme.outline.withOpacity(0.3)),
                          ),
                          boxShadow: isSelected || (_showDeleteButtons && _blinkState)
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 15,
                                  ),
                                ]
                              : [],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                category.name,
                                style: TextStyle(
                                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            // 删除按钮 - 仅在编辑模式下显示
                            if (_showDeleteButtons)
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  // 阻止事件冒泡，避免触发外部的_stopBlinking
                                  onTap: () {
                                    _showDeleteCategoryConfirmationDialog(category);
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
                      ),
                    ),
                  );
                },
                // 拖动结束时重新排序
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final category = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, category);
                  });
                },
                // 自定义构建分隔符（全部分类按钮和添加按钮）
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    child: child,
                  );
                },
                // 添加全部分类按钮和添加按钮
                header: Row(
                  children: [
                    // 使用与类别容器相同的样式，确保高度一致
                    GestureDetector(
                      onTap: () {
                        if (_showDeleteButtons) {
                          _stopBlinking();
                        } else {
                          setState(() {
                            _selectedCategoryId = null;
                          });
                          _applyFilters();
                        }
                      },
                      child: Container(
                        height: 36, // 统一高度，与类别容器匹配
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedCategoryId == null ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedCategoryId == null ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          boxShadow: _selectedCategoryId == null
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 15,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          '全部分类',
                          style: TextStyle(
                            color: _selectedCategoryId == null ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                footer: Row(
                  children: [
                    // 添加分类按钮 - 调整大小和样式，确保点击区域明显
                    GestureDetector(
                      // 阻止事件冒泡，避免触发外部的_stopBlinking
                      onTap: () {
                        _stopBlinking(); // 先停止闪烁
                        _showAddEditCategoryDialog(); // 再显示添加分类对话框
                      },
                      onLongPress: () {
                        // 阻止长按事件冒泡
                      },
                      child: Container(
                        width: 36, // 与类别容器相同高度
                        height: 36,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16, // 增大图标大小
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 批量操作栏
          if (_selectedProductIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已选择 ${_selectedProductIds.length} 件商品',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  Row(
                    children: [
                      // 批量上架
                      ElevatedButton(
                        onPressed: () => _batchChangeStatus('active'),
                        child: const Text('批量上架'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 批量下架
                      ElevatedButton(
                        onPressed: () => _batchChangeStatus('inactive'),
                        child: const Text('批量下架'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 批量修改价格
                      ElevatedButton(
                        onPressed: _batchChangePrice,
                        child: const Text('批量改价'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 批量修改库存
                      ElevatedButton(
                        onPressed: _batchChangeStock,
                        child: const Text('批量改库存'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 批量删除
                      ElevatedButton(
                        onPressed: _batchDelete,
                        child: const Text('批量删除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 批量导出
                      ElevatedButton(
                        onPressed: _batchExport,
                        child: const Text('批量导出'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // 商品列表
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 全选和商品数量
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _isSelectAll,
                            onChanged: (value) {
                              setState(() {
                                _isSelectAll = value ?? false;
                                if (_isSelectAll) {
                                  _selectedProductIds = Set<int>.from(_filteredProducts.map((product) => product.id!));
                                } else {
                                  _selectedProductIds.clear();
                                }
                              });
                            },
                            activeColor: theme.colorScheme.primary,
                            checkColor: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '全选',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '共 ${_filteredProducts.length} 件商品',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 商品列表
                  if (_filteredProducts.isEmpty)
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          '暂无商品',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _filteredProducts.map((product) => _buildProductCard(product, theme)).toList(),
                    ),
                  
                  // 加载更多指示器
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF13ec5b),
                      ),
                    ),
                  
                  // 已加载全部数据的提示
                  if (!_isLoadingMore && !_hasMoreData)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '已加载全部数据',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
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
}