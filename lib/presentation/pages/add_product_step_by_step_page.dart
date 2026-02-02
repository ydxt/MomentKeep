import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:moment_keep/core/services/storage_service.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 新增商品分步填写页面
class AddProductStepByStepPage extends ConsumerStatefulWidget {
  const AddProductStepByStepPage({super.key, this.product, required this.onSubmit});
  final StarProduct? product;
  final Future<void> Function() onSubmit;
  @override
  ConsumerState<AddProductStepByStepPage> createState() => _AddProductStepByStepPageState();
}

class _AddProductStepByStepPageState extends ConsumerState<AddProductStepByStepPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isAutoSaving = false;
  bool _isSubmitting = false;
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  SharedPreferences? _prefs;
  
  // 草稿自动保存相关
  static const String _draftKey = 'add_product_draft';
  static const Duration _autoSaveInterval = Duration(seconds: 30);
  DateTime _lastSaveTime = DateTime.now();
  
  // 视频上传相关 - 同时支持单视频和多视频
  // 单视频变量（兼容现有代码）
  File? _selectedVideo;
  String _videoPath = '';
  double _videoUploadProgress = 0.0;
  bool _isUploadingVideo = false;
  bool _isPaused = false;
  String _videoCoverPath = '';
  late VideoPlayerController _videoController;
  
  // 多视频变量（用于扩展支持）
  List<File?> _selectedVideos = [];
  List<String> _videoPaths = [];
  List<VideoPlayerController> _videoControllers = [];
  List<bool> _isVideoPlayingList = [];
  bool _isVideoPlaying = false;
  
  // 定时上架时间控制器
  late TextEditingController _scheduledReleaseTimeController;
  
  // 分类列表
  List<StarCategory> _categories = [];
  
  // 输入控制器
  late TextEditingController _productNameController;
  late TextEditingController _productCodeController;
  late TextEditingController _productIntroController;
  late TextEditingController _videoDescriptionController;
  late TextEditingController _productDetailController;
  late TextEditingController _seoTitleController;
  late TextEditingController _seoKeywordsController;
  late TextEditingController _tagInputController;
  late TextEditingController _originalPriceController;
  late TextEditingController _priceController;
  late TextEditingController _memberPriceController;
  late TextEditingController _pointsController;
  late TextEditingController _hybridPointsController;
  late TextEditingController _hybridPriceController;
  late TextEditingController _stockController;
  late TextEditingController _costPriceController;
  late TextEditingController _weightController;
  late TextEditingController _volumeController;
  late TextEditingController _shippingAddressController;
  late TextEditingController _internalNoteController;
  late TextEditingController _sortWeightController;
  late TextEditingController _limitQuantityController;
  
  // 规格名称控制器列表
  List<TextEditingController> _specNameControllers = [];
  List<TextEditingController> _specValueControllers = [];
  
  // 表单数据
  final Map<String, dynamic> _formData = {
    // 步骤1：基础信息
    'name': '',
    'productCode': '',
    'categoryId': null,
    'brand': '',
    'tags': <String>[],
    'isPreSale': false,
    'preSaleEndTime': null,
    'releaseTime': DateTime.now(),
    'scheduledReleaseTime': null,
    'isScheduledRelease': false,
    'productIntro': '',
    
    // 步骤2：图文视频
    'mainImages': <String>[],
    'videos': <String>[],
    'videoCovers': <String>[],
    'videoDescriptions': <String>[],
    'detail': '',
    'detailImages': <String>[],
    
    // 步骤3：规格与库存
    'specType': 'single', // 'single' 单规格, 'multiple' 多规格
    'specs': <Map<String, dynamic>>[],
    'skus': <Map<String, dynamic>>[],
    'stock': 0,
    'costPrice': 0,
    'weight': '',
    'volume': '',
    
    // 步骤4：价格与优惠
    'originalPrice': 0,
    'price': 0,
    'memberPrice': 0,
    'points': 0,
    'hybridPoints': 0,
    'hybridPrice': 0,
    'discountRules': <String>[],
    'participateInActivity': false,
    // 支付方式
    'supportPointsPayment': true,
    'supportCashPayment': false,
    'supportHybridPayment': false,
    
    // 步骤5：物流服务
    'shippingTemplateId': null,
    'shippingTime': '24', // 24, 48, 168 (7天)
    'shippingAddress': '',
    'returnPolicy': 'seven_days',
    
    // 步骤6：其他设置
    'sortWeight': 0,
    'isLimitedPurchase': false,
    'limitQuantity': 1,
    'internalNote': '',
    'seoTitle': '',
    'seoKeywords': '',
  };
  

  
  // 步骤标题和描述
  final List<Map<String, String>> _steps = [
    {
      'title': '基础信息',
      'description': '填写商品核心标识信息'
    },
    {
      'title': '图文视频',
      'description': '上传商品图片和视频，展示商品细节'
    },
    {
      'title': '规格与库存',
      'description': '设置商品规格和库存信息'
    },
    {
      'title': '价格与优惠',
      'description': '设置商品价格和优惠规则'
    },
    {
      'title': '物流服务',
      'description': '设置运费和发货规则'
    },
    {
      'title': '其他设置',
      'description': '补充商品其他信息'
    }
  ];
  
  @override
  void initState() {
    super.initState();
    
    // 初始化输入控制器
    _productNameController = TextEditingController(text: _formData['name']);
    _productCodeController = TextEditingController(text: _formData['productCode']);
    _productIntroController = TextEditingController(text: _formData['productIntro']);
    _videoDescriptionController = TextEditingController(text: _formData['videoDescription']);
    _productDetailController = TextEditingController(text: _formData['detail']);
    _seoTitleController = TextEditingController(text: _formData['seoTitle']);
    _seoKeywordsController = TextEditingController(text: _formData['seoKeywords']);
    _tagInputController = TextEditingController();
    _originalPriceController = TextEditingController(text: _formData['originalPrice'].toString());
    _priceController = TextEditingController(text: _formData['price'].toString());
    _memberPriceController = TextEditingController(text: _formData['memberPrice'].toString());
    _pointsController = TextEditingController(text: _formData['points'].toString());
    _hybridPointsController = TextEditingController(text: _formData['hybridPoints'].toString());
    _hybridPriceController = TextEditingController(text: _formData['hybridPrice'].toString());
    _stockController = TextEditingController(text: _formData['stock'].toString());
    _costPriceController = TextEditingController(text: _formData['costPrice'].toString());
    _weightController = TextEditingController(text: _formData['weight'].toString());
    _volumeController = TextEditingController(text: _formData['volume'].toString());
    _shippingAddressController = TextEditingController(text: _formData['shippingAddress'].toString());
    _internalNoteController = TextEditingController(text: _formData['internalNote'].toString());
    _sortWeightController = TextEditingController(text: _formData['sortWeight'].toString());
    _limitQuantityController = TextEditingController(text: _formData['limitQuantity'].toString());
    
    // 初始化定时上架时间控制器
    _scheduledReleaseTimeController = TextEditingController();
    
    // 初始化视频控制器列表
    _videoControllers = [];
    _isVideoPlayingList = [];
    
    _loadData();
    _initSharedPreferences();
    _startAutoSave();
    
    if (widget.product != null) {
      _loadProductData();
    } else {
      _generateProductCode();
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    
    // 释放视频控制器列表
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    
    // 释放输入控制器
    _productNameController.dispose();
    _productCodeController.dispose();
    _productIntroController.dispose();
    _videoDescriptionController.dispose();
    _productDetailController.dispose();
    _seoTitleController.dispose();
    _seoKeywordsController.dispose();
    _tagInputController.dispose();
    _originalPriceController.dispose();
    _priceController.dispose();
    _memberPriceController.dispose();
    _pointsController.dispose();
    _hybridPointsController.dispose();
    _hybridPriceController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _shippingAddressController.dispose();
    _internalNoteController.dispose();
    _sortWeightController.dispose();
    _limitQuantityController.dispose();
    _scheduledReleaseTimeController.dispose();
    
    // 释放规格控制器列表
    for (var controller in _specNameControllers) {
      controller.dispose();
    }
    for (var controller in _specValueControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }
  
  /// 初始化SharedPreferences
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadDraft();
  }
  
  /// 加载草稿
  Future<void> _loadDraft() async {
    if (_prefs == null) return;
    
    final draftJson = _prefs!.getString(_draftKey);
    if (draftJson != null && widget.product == null) {
      try {
        final draftData = jsonDecode(draftJson);
        setState(() {
          _formData.addAll(Map<String, dynamic>.from(draftData));
        });
      } catch (e) {
        debugPrint('加载草稿失败: $e');
      }
    }
  }
  
  /// 保存草稿
  Future<void> _saveDraft() async {
    if (_prefs == null) return;
    
    setState(() {
      _isAutoSaving = true;
    });
    
    try {
      // 创建_formData的副本，用于序列化
      final Map<String, dynamic> draftData = Map.from(_formData);
      
      // 将DateTime字段转换为字符串
      if (draftData['releaseTime'] is DateTime) {
        draftData['releaseTime'] = draftData['releaseTime'].toIso8601String();
      }
      if (draftData['preSaleEndTime'] is DateTime) {
        draftData['preSaleEndTime'] = draftData['preSaleEndTime'].toIso8601String();
      }
      if (draftData['scheduledReleaseTime'] is DateTime) {
        draftData['scheduledReleaseTime'] = draftData['scheduledReleaseTime'].toIso8601String();
      }
      
      final draftJson = jsonEncode(draftData);
      await _prefs!.setString(_draftKey, draftJson);
      _lastSaveTime = DateTime.now();
    } catch (e) {
      debugPrint('保存草稿失败: $e');
    } finally {
      setState(() {
        _isAutoSaving = false;
      });
    }
  }
  
  /// 启动自动保存
  void _startAutoSave() {
    Future.delayed(_autoSaveInterval, () {
      if (mounted) {
        final now = DateTime.now();
        if (now.difference(_lastSaveTime) >= _autoSaveInterval) {
          _saveDraft();
        }
        _startAutoSave();
      }
    });
  }
  
  /// 加载分类数据
  Future<void> _loadData() async {
    try {
      final categories = await _databaseService.getAllStarCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('加载分类数据失败: $e');
    }
  }
  
  /// 显示分类选择对话框
  String _getSelectedCategoryName() {
    if (_formData['categoryId'] == null) return '选择分类';
    try {
      final category = _categories.firstWhere((c) => c.id == _formData['categoryId']);
      return category.name;
    } catch (e) {
      return '已选分类';
    }
  }
  
  /// 显示新建分类对话框
  void _showNewCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();
    final theme = ref.watch(currentThemeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('新建分类', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: TextField(
          controller: categoryController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '请输入分类名称',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
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
            onPressed: () async {
              if (categoryController.text.isNotEmpty) {
                // 创建新分类
                final newCategory = StarCategory(
                  name: categoryController.text,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                // 保存到数据库
                await _databaseService.insertStarCategory(newCategory);
                
                // 重新加载分类列表
                await _loadData();
                
                // 设置为当前选择的分类
                setState(() {
                  _formData['categoryId'] = newCategory.id;
                });
                
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  void _showCategorySelectionDialog() {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('选择分类', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var category in _categories) ...[
                ListTile(
                  title: Text(category.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    setState(() {
                      _formData['categoryId'] = category.id;
                    });
                    Navigator.pop(context);
                  },
                ),
                if (category != _categories.last) ...[
                  Divider(color: theme.colorScheme.outline),
                ],
              ],
              // 添加新建分类选项
              ListTile(
                title: Text('新建分类', style: TextStyle(color: theme.colorScheme.primary)),
                trailing: Icon(Icons.add, color: theme.colorScheme.primary),
                onTap: () {
                  Navigator.pop(context);
                  _showNewCategoryDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
  
  /// 显示新建品牌对话框
  void _showNewBrandDialog() {
    final TextEditingController brandController = TextEditingController();
    final theme = ref.watch(currentThemeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('新建品牌', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: TextField(
          controller: brandController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '请输入品牌名称',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
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
            onPressed: () {
              if (brandController.text.isNotEmpty) {
                setState(() {
                  _formData['brand'] = brandController.text;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 生成商品编码
  void _generateProductCode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = timestamp % 1000;
    final productCode = 'SP${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$timestamp$random';
    
    setState(() {
      _formData['productCode'] = productCode;
      _productCodeController.text = productCode;
    });
  }
  
  /// 加载商品数据
  void _loadProductData() {
    final product = widget.product!;
    setState(() {
      // 步骤1：基础信息
      _formData['name'] = product.name;
      _formData['productCode'] = product.productCode;
      _formData['categoryId'] = product.categoryId;
      _formData['brand'] = product.brand ?? '';
      _formData['tags'] = List<String>.from(product.tags);
      _formData['isPreSale'] = product.isPreSale;
      _formData['preSaleEndTime'] = product.preSaleEndTime;
      _formData['releaseTime'] = product.releaseTime ?? DateTime.now();
      _formData['scheduledReleaseTime'] = product.scheduledReleaseTime;
      _formData['isScheduledRelease'] = product.scheduledReleaseTime != null;
      _formData['productIntro'] = product.description ?? '';
      
      // 步骤2：图文视频
      _formData['mainImages'] = product.mainImages.isNotEmpty ? List<String>.from(product.mainImages) : [product.image];
      _formData['detail'] = product.detail ?? product.description ?? '';
      _formData['videos'] = product.video != null ? [product.video!] : [];
      _formData['videoCovers'] = product.videoCover != null ? [product.videoCover!] : [];
      _formData['videoDescriptions'] = product.videoDescription != null ? [product.videoDescription!] : [];
      _formData['detailImages'] = product.detailImages.isNotEmpty ? List<String>.from(product.detailImages) : [];
      
      // 步骤3：规格与库存
      _formData['stock'] = product.stock;
      _formData['costPrice'] = product.costPrice;
      _formData['weight'] = product.weight ?? '';
      _formData['volume'] = product.volume ?? '';
      
      // 步骤4：价格与优惠
      _formData['points'] = product.points;
      _formData['originalPrice'] = product.originalPrice;
      _formData['price'] = product.price;
      _formData['memberPrice'] = product.memberPrice;
      _formData['hybridPoints'] = product.hybridPoints;
      _formData['hybridPrice'] = product.hybridPrice;
      _formData['supportPointsPayment'] = product.supportPointsPayment;
      _formData['supportCashPayment'] = product.supportCashPayment;
      _formData['supportHybridPayment'] = product.supportHybridPayment;
      
      // 步骤5：物流服务
      _formData['shippingTemplateId'] = product.shippingTemplateId;
      _formData['shippingTime'] = product.shippingTime ?? '24';
      _formData['shippingAddress'] = product.shippingAddress ?? '';
      _formData['returnPolicy'] = product.returnPolicy ?? 'seven_days';
      
      // 步骤6：其他设置
      _formData['sortWeight'] = product.sortWeight;
      _formData['isLimitedPurchase'] = product.isLimitedPurchase;
      _formData['limitQuantity'] = product.limitQuantity;
      _formData['internalNote'] = product.internalNote ?? '';
      _formData['seoTitle'] = product.seoTitle ?? '';
      _formData['seoKeywords'] = product.seoKeywords ?? '';
      
      // 规格和SKU处理
      if (product.skus != null && product.skus!.isNotEmpty) {
        _formData['specType'] = 'multiple';
        _formData['skus'] = product.skus!.map((sku) => sku.toMap()).toList();
      } else {
        // 单规格商品
        _formData['specType'] = 'single';
      }
      
      // 规格信息
      if (product.specs != null && product.specs!.isNotEmpty) {
        _formData['specs'] = product.specs!.map((spec) => spec.toMap()).toList();
      } else {
        _formData['specs'] = [];
      }
      
      // 初始化specNameControllers和specValueControllers
      if (_formData['specs'].isNotEmpty) {
        // 清空现有控制器
        _specNameControllers.clear();
        _specValueControllers.clear();
        
        // 为每个规格添加控制器
        for (var spec in _formData['specs']) {
          _specNameControllers.add(TextEditingController(text: spec['name'] ?? ''));
          _specValueControllers.add(TextEditingController(text: (spec['values'] as List).join(',')));
        }
      }
    });
    
    // 更新控制器的值
    _productNameController.text = product.name;
    _productCodeController.text = product.productCode;
    _productIntroController.text = product.description ?? '';
    _productDetailController.text = product.detail ?? product.description ?? '';
    _videoDescriptionController.text = product.videoDescription ?? '';
    _seoTitleController.text = product.seoTitle ?? '';
    _seoKeywordsController.text = product.seoKeywords ?? '';
    
    // 价格控制器
    _originalPriceController.text = product.originalPrice > 0 ? product.originalPrice.toString() : '';
    _priceController.text = product.price > 0 ? product.price.toString() : '';
    _memberPriceController.text = product.memberPrice > 0 ? product.memberPrice.toString() : '';
    _pointsController.text = product.points > 0 ? product.points.toString() : '';
    _hybridPointsController.text = product.hybridPoints > 0 ? product.hybridPoints.toString() : '';
    _hybridPriceController.text = product.hybridPrice > 0 ? product.hybridPrice.toString() : '';
    
    // 库存和成本价控制器
    _stockController.text = product.stock.toString();
    _costPriceController.text = (product.costPrice / 1000).toString(); // 转换为元
    
    // 物流相关控制器
    _shippingAddressController.text = product.shippingAddress ?? '';
    
    // 重量和体积控制器
    _weightController.text = product.weight ?? '';
    _volumeController.text = product.volume ?? '';
    
    // 其他设置控制器
    _internalNoteController.text = product.internalNote ?? '';
    _sortWeightController.text = product.sortWeight.toString();
    _limitQuantityController.text = product.limitQuantity.toString();
    
    // 定时上架时间控制器更新
    if (product.scheduledReleaseTime != null) {
      setState(() {
        _formData['isScheduledRelease'] = true;
        _scheduledReleaseTimeController.text = '${product.scheduledReleaseTime!.year}-${product.scheduledReleaseTime!.month.toString().padLeft(2, '0')}-${product.scheduledReleaseTime!.day.toString().padLeft(2, '0')} ${product.scheduledReleaseTime!.hour.toString().padLeft(2, '0')}:${product.scheduledReleaseTime!.minute.toString().padLeft(2, '0')}';
      });
    }
    
    // 视频控制器初始化
    if (product.video != null && product.video!.isNotEmpty) {
      setState(() {
        _videoPath = product.video!;
        // 初始化视频控制器，加载已上传的视频
        _videoController = VideoPlayerController.networkUrl(Uri.parse(product.video!))
          ..initialize().then((_) {
            setState(() {
              _isVideoPlaying = false;
            });
          });
        // 更新多视频列表
        _videoPaths = [product.video!];
        _videoControllers = [_videoController];
      });
    }
  }
  
  /// 插入表格
  void _insertTable() {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController rowsController = TextEditingController(text: '3');
        final TextEditingController columnsController = TextEditingController(text: '2');
        
        final List<String> headers = ['', ''];
        final List<List<String>> dataRows = [['', ''], ['', ''], ['', '']];
        
        void updateGrid() {
          final newRows = int.tryParse(rowsController.text) ?? 3;
          final newCols = int.tryParse(columnsController.text) ?? 2;
          
          while (headers.length < newCols) headers.add('');
          while (headers.length > newCols) headers.removeLast();
          
          while (dataRows.length < newRows) {
            final newRow = List<String>.filled(newCols, '');
            dataRows.add(newRow);
          }
          while (dataRows.length > newRows) {
            dataRows.removeLast();
          }
          for (var row in dataRows) {
            while (row.length < newCols) row.add('');
            while (row.length > newCols) row.removeLast();
          }
        }
        
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('插入表格', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('行数:', style: TextStyle(color: theme.colorScheme.onSurface)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: rowsController,
                            onChanged: (_) {
                              updateGrid();
                              setState(() {});
                            },
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.colorScheme.outline),
                              ),
                              contentPadding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('列数:', style: TextStyle(color: theme.colorScheme.onSurface)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: columnsController,
                            onChanged: (_) {
                              updateGrid();
                              setState(() {});
                            },
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.colorScheme.outline),
                              ),
                              contentPadding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('表格内容:', style: TextStyle(color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(headers.length, (colIndex) {
                                return SizedBox(
                                  width: 110,
                                  child: TextField(
                                    onChanged: (value) {
                                      headers[colIndex] = value;
                                    },
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '列${colIndex + 1}',
                                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(color: theme.colorScheme.outline),
                                      ),
                                      contentPadding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            ...List.generate(dataRows.length, (rowIndex) {
                              return Row(
                                children: List.generate(dataRows[rowIndex].length, (colIndex) {
                                  return SizedBox(
                                    width: 110,
                                    child: TextField(
                                      onChanged: (value) {
                                        dataRows[rowIndex][colIndex] = value;
                                      },
                                      style: TextStyle(color: theme.colorScheme.onSurface),
                                      decoration: InputDecoration(
                                        hintText: '${rowIndex + 1},${colIndex + 1}',
                                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: theme.colorScheme.outline),
                                        ),
                                        contentPadding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '提示：直接在表格单元格中输入内容，完成后点击"插入"按钮',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                final validHeaders = headers.where((h) => h.isNotEmpty).toList();
                if (validHeaders.isEmpty) {
                  validHeaders.addAll(List.filled(headers.length, ' '));
                }
                
                String tableText = '\n【表格】\n';
                tableText += '|' + validHeaders.join('|') + '|\n';
                tableText += '|' + validHeaders.map((_) => '---').join('|') + '|\n';
                
                for (var row in dataRows) {
                  final validRow = row.where((c) => c.isNotEmpty).toList();
                  if (validRow.isNotEmpty) {
                    tableText += '|' + validRow.join('|') + '|\n';
                  }
                }
                
                tableText += '【表格结束】\n';
                
                final currentText = _productDetailController.text;
                _productDetailController.text = currentText + tableText;
                _formData['detail'] = _productDetailController.text;
                
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('插入'),
            ),
          ],
        );
      },
    );
  }
  
  /// 生成SKU列表
  void _generateSkus() {
    if (_formData['specs'].isEmpty) {
      return;
    }
    
    // 生成所有规格组合
    final List<List<String>> specCombinations = [];
    for (var spec in _formData['specs']) {
      final values = List<String>.from((spec['values'] as List?) ?? []);
      if (values.isEmpty) continue;
      if (specCombinations.isEmpty) {
        for (var value in values) {
          specCombinations.add([value]);
        }
      } else {
        final newCombinations = <List<String>>[];
        for (var existingCombination in specCombinations) {
          for (var value in values) {
            final newCombination = List<String>.from(existingCombination)..add(value);
            newCombinations.add(newCombination);
          }
        }
        specCombinations.clear();
        specCombinations.addAll(newCombinations);
      }
    }
    
    // 生成SKU
    final skus = <Map<String, dynamic>>[];
    for (var i = 0; i < specCombinations.length; i++) {
      final combination = specCombinations[i];
      final specValues = <String, String>{};
      
      int combinationIndex = 0;
      for (var j = 0; j < _formData['specs'].length; j++) {
        final spec = _formData['specs'][j];
        final values = List<String>.from((spec['values'] as List?) ?? []);
        if (values.isEmpty) continue;
        
        final specName = spec['name'];
        if (combinationIndex < combination.length) {
          specValues[specName] = combination[combinationIndex];
          combinationIndex++;
        }
      }
      
      // 处理空字符串的情况，转换为正确的数值
      final price = int.tryParse(_formData['price'].toString()) ?? 0;
      final points = int.tryParse(_formData['points'].toString()) ?? 0;
      final hybridPrice = int.tryParse(_formData['hybridPrice'].toString()) ?? 0;
      final hybridPoints = int.tryParse(_formData['hybridPoints'].toString()) ?? 0;
      final costPrice = _formData['costPrice'] is double 
          ? (_formData['costPrice'] * 1000).round() 
          : (_formData['costPrice'] as int? ?? 0);
      final stock = int.tryParse(_formData['stock'].toString()) ?? 0;
      
      final sku = {
        'skuCode': '${_formData['productCode']}-${i+1}',
        'specValues': specValues,
        'price': price,
        'points': points,
        'hybridPrice': hybridPrice,
        'hybridPoints': hybridPoints,
        'costPrice': costPrice,
        'stock': stock,
        'image': '',
        // 支付方式相关字段
        'supportPointsPayment': _formData['supportPointsPayment'] ?? true,
        'supportCashPayment': _formData['supportCashPayment'] ?? true,
        'supportHybridPayment': _formData['supportHybridPayment'] ?? true,
      };
      
      skus.add(sku);
    }
    
    setState(() {
      _formData['skus'] = skus;
    });
  }
  
  /// 上传视频
  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) return;
    
    setState(() {
      _isUploadingVideo = true;
      _videoUploadProgress = 0.0;
      _isPaused = false;
    });
    
    try {
      // 模拟视频上传进度
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isPaused) {
          setState(() {
            _videoUploadProgress = i / 10;
          });
        }
      }
      
      // 实际上传逻辑
      final userId = 'user_123'; // 应该从用户系统获取
      final videoPath = await _storageService.storeFile(
        XFile(_selectedVideo!.path),
        fileType: 'product_video',
        userId: userId,
        isStore: true,
      );
      
      setState(() {
        // 更新多视频列表
        _videoPaths.add(videoPath);
        final videos = List<String>.from(_formData['videos'] ?? []);
        videos.add(videoPath);
        _formData['videos'] = videos;
        
        // 确保单视频字段也有值（兼容现有代码）
        if (_videoPath.isEmpty) {
          _videoPath = videoPath;
          _formData['video'] = videoPath;
        }
        
        // 初始化新视频的控制器
        final newController = VideoPlayerController.networkUrl(Uri.parse(videoPath))
          ..initialize().then((_) {
            setState(() {
              // 控制器初始化完成后不需要额外操作
            });
          });
          
        // 更新视频控制器列表
        _videoControllers.add(newController);
        _isVideoPlayingList.add(false);
        
        // 重置上传状态
        _isUploadingVideo = false;
        _selectedVideo = null;
      });
    } catch (e) {
      debugPrint('视频上传失败: $e');
      setState(() {
        _isUploadingVideo = false;
        _selectedVideo = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('视频上传失败: $e')),
      );
    }
  }
  

  
  /// 选择视频
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final sizeInMB = file.lengthSync() / (1024 * 1024);
      
      // 验证视频大小
      if (sizeInMB > 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频大小超过500M，请压缩后重新上传')),
        );
        return;
      }
      
      setState(() {
        // 设置单视频变量（兼容现有代码）
        _selectedVideo = file;
        
        // 添加到多视频列表
        _selectedVideos.add(file);
      });
      
      // 开始上传
      _uploadVideo();
    }
  }
  
  /// 选择图片
  Future<void> _pickImages(int maxCount, void Function(List<String>) onImagesSelected) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFiles.isNotEmpty) {
      final images = <String>[];
      final userId = 'user_123'; // 应该从用户系统获取
      
      for (final pickedFile in pickedFiles.take(maxCount)) {
        try {
          final imagePath = await _storageService.storeFile(
            XFile(pickedFile.path),
            fileType: 'product_image',
            userId: userId,
            isStore: true,
          );
          images.add(imagePath);
        } catch (e) {
          debugPrint('图片上传失败: $e');
        }
      }
      
      if (images.isNotEmpty) {
        onImagesSelected(images);
      }
    }
  }
  
  /// 验证当前步骤
  bool _validateCurrentStep() {
    List<String> errors = [];
    
    switch (_currentStep) {
      case 0: // 基础信息
        if (_formData['name'].isEmpty) {
          errors.add('请输入商品名称');
        } else if ((_formData['name'] as String).length > 60) {
          errors.add('商品名称不能超过60个字符');
        }
        
        if (_formData['productCode'].isEmpty) {
          errors.add('请输入商品编码');
        }
        
        if (_formData['categoryId'] == null) {
          errors.add('请选择所属分类');
        }
        
        if (_formData['isPreSale'] && _formData['preSaleEndTime'] == null) {
          errors.add('请设置预售结束时间');
        }
        
        if (_formData['isScheduledRelease'] && _formData['scheduledReleaseTime'] == null) {
          errors.add('请设置定时上架时间');
        }
        break;
        
      case 1: // 图文视频
        if ((_formData['mainImages'] as List).isEmpty) {
          errors.add('请上传商品主图');
        } else if ((_formData['mainImages'] as List).length < 3) {
          errors.add('建议上传3-5张商品主图');
        }
        
        if (_formData['detail'].isEmpty) {
          errors.add('请输入商品详情');
        }
        break;
        
      case 2: // 规格与库存
        if (_formData['specType'] == 'single') {
          if (_formData['stock'] < 0) {
            errors.add('库存不能为负数');
          }
        } else {
          if ((_formData['specs'] as List).isEmpty) {
            errors.add('请添加规格项');
          }
          
          if ((_formData['skus'] as List).isEmpty) {
            errors.add('请生成SKU');
          } else {
            // 验证每个SKU
            for (var sku in _formData['skus']) {
              if (sku['price'] < 0) {
                errors.add('SKU价格不能为负数');
                break;
              }
              if (sku['stock'] < 0) {
                errors.add('SKU库存不能为负数');
                break;
              }
            }
          }
        }
        break;
        
      case 3: // 价格与优惠
        final price = int.tryParse(_formData['price'].toString()) ?? 0;
        final points = int.tryParse(_formData['points'].toString()) ?? 0;
        final originalPrice = int.tryParse(_formData['originalPrice'].toString()) ?? 0;
        final memberPrice = int.tryParse(_formData['memberPrice'].toString()) ?? 0;
        
        if (price <= 0) {
          errors.add('售价必须大于0');
        }
        
        if (points < 0) {
          errors.add('积分不能为负数');
        }
        
        if (originalPrice > 0 && originalPrice < price) {
          errors.add('原价不能低于售价');
        }
        
        if (memberPrice > 0 && memberPrice > price) {
          errors.add('会员价不能高于售价');
        }
        break;
        
      case 4: // 物流服务
        if (_formData['shippingTemplateId'] == null) {
          errors.add('请选择运费模板');
        }
        
        if (_formData['shippingAddress'].isEmpty) {
          errors.add('请输入发货地址');
        }
        break;
        
      case 5: // 其他设置
        // 可选步骤，不做强制验证
        break;
    }
    
    if (errors.isNotEmpty) {
      // 显示错误信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: errors.map((error) => Text('- $error')).toList(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    
    return true;
  }
  
  /// 提交表单
  Future<void> _submitForm() async {
    debugPrint('开始提交表单，当前步骤: $_currentStep');
    
    if (!_validateCurrentStep()) {
      debugPrint('当前步骤验证失败');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完成当前步骤的必填项')),
      );
      return;
    }
    
    if (_currentStep < 5) {
      debugPrint('准备前往下一步，当前步骤: $_currentStep，目标步骤: ${_currentStep + 1}');
      // 先更新状态，再前往下一步
      setState(() {
        _currentStep++;
        debugPrint('状态更新成功，当前步骤: $_currentStep');
      });
      debugPrint('准备跳转页面，目标步骤: $_currentStep');
      _pageController.jumpToPage(_currentStep);
      debugPrint('页面跳转成功');
    } else {
      debugPrint('准备提交表单');
      // 提交表单
      _saveDraft();
      _submitProduct();
    }
  }
  
  /// 保存为草稿到数据库
  Future<void> _saveAsDraftToDatabase() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final now = DateTime.now();
      // 转换成本价为int类型，乘以1000以保留3位小数精度
      final costPrice = _formData['costPrice'] is double 
          ? (_formData['costPrice'] * 1000).round() 
          : (_formData['costPrice'] as int? ?? 0);
          
      // 从视频列表中获取第一个视频作为主要视频
      final videos = List<String>.from(_formData['videos']);
      final videoCovers = List<String>.from(_formData['videoCovers']);
      final videoDescriptions = List<String>.from(_formData['videoDescriptions']);
      
      // 创建草稿商品
      final draftProduct = StarProduct(
        id: widget.product?.id,
        name: _formData['name'].isNotEmpty ? _formData['name'] : '未命名商品',
        description: _formData['detail'],
        image: (_formData['mainImages'] as List).isNotEmpty ? _formData['mainImages'].first : '',
        mainImages: List<String>.from(_formData['mainImages']),
        productCode: _formData['productCode'],
        points: _formData['points'],
        hybridPoints: _formData['hybridPoints'],
        hybridPrice: _formData['hybridPrice'],
        costPrice: costPrice,
        stock: _formData['stock'],
        categoryId: _formData['categoryId'] ?? 0, // 设置默认值0
        brand: _formData['brand'],
        tags: List<String>.from(_formData['tags']),
        categoryPath: widget.product?.categoryPath,
        isActive: false,
        isDeleted: false,
        status: 'draft', // 设置状态为草稿
        shippingTemplateId: _formData['shippingTemplateId'],
        isPreSale: _formData['isPreSale'],
        preSaleEndTime: _formData['preSaleEndTime'],
        releaseTime: null, // 草稿商品不上架
        scheduledReleaseTime: null,
        sales7Days: widget.product?.sales7Days ?? 0,
        totalSales: widget.product?.totalSales ?? 0,
        visitors: widget.product?.visitors ?? 0,
        conversionRate: widget.product?.conversionRate ?? 0.0,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
        deletedAt: widget.product?.deletedAt,
        skus: _formData['specType'] == 'multiple' && _formData['skus'] != null
            ? (_formData['skus'] as List).map((skuMap) {
                final map = Map<String, dynamic>.from(skuMap);
                return StarProductSku(
                  productId: widget.product?.id ?? 0,
                  skuCode: map['skuCode'] ?? '',
                  specValues: Map<String, dynamic>.from(map['specValues'] ?? {}),
                  price: map['price'] ?? 0,
                  points: map['points'] ?? 0,
                  hybridPrice: map['hybridPrice'] ?? 0,
                  hybridPoints: map['hybridPoints'] ?? 0,
                  costPrice: map['costPrice'] ?? 0,
                  stock: map['stock'] ?? 0,
                  image: map['image'] ?? '',
                  sortOrder: map['sortOrder'] ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isDeleted: false,
                  supportPointsPayment: map['supportPointsPayment'] ?? _formData['supportPointsPayment'] ?? true,
                  supportCashPayment: map['supportCashPayment'] ?? _formData['supportCashPayment'] ?? true,
                  supportHybridPayment: map['supportHybridPayment'] ?? _formData['supportHybridPayment'] ?? true,
                );
              }).toList()
            : widget.product?.skus ?? [],
        specs: _formData['specType'] == 'multiple' && _formData['specs'] != null
            ? (_formData['specs'] as List).map((specMap) {
                final map = Map<String, dynamic>.from(specMap);
                return StarProductSpec(
                  productId: widget.product?.id ?? 0,
                  name: map['name'] ?? '',
                  values: List<String>.from(map['values'] ?? []),
                  sortOrder: map['sort_order'] ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }).toList()
            : widget.product?.specs ?? [],
        video: videos.isNotEmpty ? videos.first : null,
        videoCover: videoCovers.isNotEmpty ? videoCovers.first : null,
        videoDescription: videoDescriptions.isNotEmpty ? videoDescriptions.first : null,
        detailImages: List<String>.from(_formData['detailImages']),
        detail: _formData['detail'],
        weight: _formData['weight'],
        volume: _formData['volume'],
        originalPrice: _formData['originalPrice'],
        price: _formData['price'],
        memberPrice: _formData['memberPrice'],
        shippingTime: _formData['shippingTime'],
        shippingAddress: _formData['shippingAddress'],
        returnPolicy: _formData['returnPolicy'],
        sortWeight: _formData['sortWeight'],
        isLimitedPurchase: _formData['isLimitedPurchase'],
        limitQuantity: _formData['limitQuantity'],
        internalNote: _formData['internalNote'],
        seoTitle: _formData['seoTitle'],
        seoKeywords: _formData['seoKeywords'],
        supportPointsPayment: _formData['supportPointsPayment'],
        supportCashPayment: _formData['supportCashPayment'],
        supportHybridPayment: _formData['supportHybridPayment'],
      );
      
      // 保存到数据库
      if (widget.product?.id != null) {
        await _databaseService.updateStarProduct(draftProduct);
      } else {
        await _databaseService.insertStarProduct(draftProduct);
      }
      
      // 清除本地草稿
      if (_prefs != null) {
        await _prefs!.remove(_draftKey);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('草稿已保存')),
      );
      
      // 返回商品管理页面
      await widget.onSubmit();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('保存草稿失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存草稿失败: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  /// 提交商品
  Future<void> _submitProduct() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final now = DateTime.now();
      // 转换成本价为int类型，乘以1000以保留3位小数精度
      final costPrice = _formData['costPrice'] is double 
          ? (_formData['costPrice'] * 1000).round() 
          : (_formData['costPrice'] as int? ?? 0);
          
      // 从视频列表中获取第一个视频作为主要视频
      final videos = List<String>.from(_formData['videos']);
      final videoCovers = List<String>.from(_formData['videoCovers']);
      final videoDescriptions = List<String>.from(_formData['videoDescriptions']);
      
      final product = StarProduct(
        id: widget.product?.id,
        name: _formData['name'],
        description: _formData['detail'],
        image: (_formData['mainImages'] as List).isNotEmpty ? _formData['mainImages'].first : '',
        mainImages: List<String>.from(_formData['mainImages']),
        productCode: _formData['productCode'],
        points: _formData['points'],
        hybridPoints: _formData['hybridPoints'],
        hybridPrice: _formData['hybridPrice'],
        costPrice: costPrice,
        stock: _formData['stock'],
        categoryId: _formData['categoryId'],
        brand: _formData['brand'],
        tags: List<String>.from(_formData['tags']),
        categoryPath: widget.product?.categoryPath,
        isActive: true,
        isDeleted: false,
        status: 'approved',
        shippingTemplateId: _formData['shippingTemplateId'],
        isPreSale: _formData['isPreSale'],
        preSaleEndTime: _formData['preSaleEndTime'],
        releaseTime: _formData['isScheduledRelease'] ? null : now,
        scheduledReleaseTime: _formData['isScheduledRelease'] ? _formData['scheduledReleaseTime'] : null,
        sales7Days: widget.product?.sales7Days ?? 0,
        totalSales: widget.product?.totalSales ?? 0,
        visitors: widget.product?.visitors ?? 0,
        conversionRate: widget.product?.conversionRate ?? 0.0,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
        deletedAt: widget.product?.deletedAt,
        skus: _formData['specType'] == 'multiple' && _formData['skus'] != null
            ? (_formData['skus'] as List).map((skuMap) {
                final map = Map<String, dynamic>.from(skuMap);
                return StarProductSku(
                  productId: widget.product?.id ?? 0,
                  skuCode: map['skuCode'] ?? '',
                  specValues: Map<String, dynamic>.from(map['specValues'] ?? {}),
                  price: map['price'] ?? 0,
                  points: map['points'] ?? 0,
                  hybridPrice: map['hybridPrice'] ?? 0,
                  hybridPoints: map['hybridPoints'] ?? 0,
                  costPrice: map['costPrice'] ?? 0,
                  stock: map['stock'] ?? 0,
                  image: map['image'] ?? '',
                  sortOrder: map['sortOrder'] ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isDeleted: false,
                  supportPointsPayment: map['supportPointsPayment'] ?? _formData['supportPointsPayment'] ?? true,
                  supportCashPayment: map['supportCashPayment'] ?? _formData['supportCashPayment'] ?? true,
                  supportHybridPayment: map['supportHybridPayment'] ?? _formData['supportHybridPayment'] ?? true,
                );
              }).toList()
            : widget.product?.skus ?? [],
        specs: _formData['specType'] == 'multiple' && _formData['specs'] != null
            ? (_formData['specs'] as List).map((specMap) {
                final map = Map<String, dynamic>.from(specMap);
                return StarProductSpec(
                  productId: widget.product?.id ?? 0,
                  name: map['name'] ?? '',
                  values: List<String>.from(map['values'] ?? []),
                  sortOrder: map['sort_order'] ?? 0,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }).toList()
            : widget.product?.specs ?? [],
        video: videos.isNotEmpty ? videos.first : null,
        videoCover: videoCovers.isNotEmpty ? videoCovers.first : null,
        videoDescription: videoDescriptions.isNotEmpty ? videoDescriptions.first : null,
        detailImages: List<String>.from(_formData['detailImages']),
        detail: _formData['detail'],
        weight: _formData['weight'],
        volume: _formData['volume'],
        originalPrice: _formData['originalPrice'],
        price: _formData['price'],
        memberPrice: _formData['memberPrice'],
        shippingTime: _formData['shippingTime'],
        shippingAddress: _formData['shippingAddress'],
        returnPolicy: _formData['returnPolicy'],
        sortWeight: _formData['sortWeight'],
        isLimitedPurchase: _formData['isLimitedPurchase'],
        limitQuantity: _formData['limitQuantity'],
        internalNote: _formData['internalNote'],
        seoTitle: _formData['seoTitle'],
        seoKeywords: _formData['seoKeywords'],
        supportPointsPayment: _formData['supportPointsPayment'],
        supportCashPayment: _formData['supportCashPayment'],
        supportHybridPayment: _formData['supportHybridPayment'],
      );
      
      // 保存商品
      if (widget.product?.id != null) {
        await _databaseService.updateStarProduct(product);
      } else {
        await _databaseService.insertStarProduct(product);
      }
      
      // 保存SKU和规格（如果是多规格）
      // 注意：当前数据库服务不支持规格和SKU管理，相关功能将在后续版本实现
      if (_formData['specType'] == 'multiple') {
        // TODO: 实现规格和SKU的保存功能
        debugPrint('多规格商品已保存，但规格和SKU详情将在后续版本实现');
      }
      
      // 清除草稿
      if (_prefs != null) {
        await _prefs!.remove(_draftKey);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品提交成功，已自动通过审核')),
      );
      
      // 等待onSubmit完成后再关闭页面
      await widget.onSubmit();
      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('提交商品失败: $e');
      debugPrint('完整错误: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      debugPrint('错误类型: ${e.runtimeType}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交商品失败: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  

  
  /// 批量设置SKU价格
  void _batchSetSkuPrice(int price) {
    setState(() {
      for (var sku in _formData['skus']) {
        sku['price'] = price;
      }
    });
  }
  
  /// 批量设置SKU成本价
  void _batchSetSkuCostPrice(int costPrice) {
    setState(() {
      for (var sku in _formData['skus']) {
        sku['costPrice'] = costPrice;
      }
    });
  }
  
  /// 批量设置SKU库存
  void _batchSetSkuStock(int stock) {
    setState(() {
      for (var sku in _formData['skus']) {
        sku['stock'] = stock;
      }
    });
  }
  

  
  /// 渲染当前步骤内容
  Widget _buildStepContent({required int stepIndex}) {
    switch (stepIndex) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildMediaStep();
      case 2:
        return _buildSpecStockStep();
      case 3:
        return _buildPriceStep();
      case 4:
        return _buildShippingStep();
      case 5:
        return _buildOtherStep();
      default:
        return const SizedBox();
    }
  }
  
  /// 步骤1：基础信息
  Widget _buildBasicInfoStep() {
    final theme = ref.watch(currentThemeProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品名称
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '商品名称 *',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _formData['name'] = value;
                            });
                          },
                          controller: _productNameController,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          maxLength: 60,
                          decoration: InputDecoration(
                            hintText: '例如：男士纯棉T恤',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                        )
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: 实现查重功能
                        },
                        icon: Icon(Icons.manage_search, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 商品编码
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '商品编码',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: _generateProductCode,
                      child: Row(
                        children: [
                          Icon(Icons.autorenew, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '自动生成',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _formData['productCode'] = value;
                            });
                          },
                          controller: _productCodeController,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Monospace',
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                        )
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: 实现编辑功能
                        },
                        icon: Icon(Icons.edit, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 所属分类
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '所属分类 *',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showCategorySelectionDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formData['categoryId'] != null ? _getSelectedCategoryName() : '选择分类',
                            style: TextStyle(
                              color: _formData['categoryId'] != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 品牌
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '品牌 (选填)',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _formData['brand'].isEmpty ? null : _formData['brand'],
                      hint: Text(
                        '选择品牌',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
                      dropdownColor: theme.colorScheme.surface,
                      icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                      items: [
                        // 固定品牌选项
                        const DropdownMenuItem<String>(
                          value: 'Nike',
                          child: Text('Nike'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Adidas',
                          child: Text('Adidas'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'Puma',
                          child: Text('Puma'),
                        ),
                        // 动态添加自定义品牌选项（如果存在）
                        if (_formData['brand'].isNotEmpty && 
                            !['Nike', 'Adidas', 'Puma'].contains(_formData['brand'])) ...[
                          DropdownMenuItem<String>(
                            value: _formData['brand'],
                            child: Text(_formData['brand']),
                          ),
                        ],
                        // 新建品牌选项
                        DropdownMenuItem<String>(
                          value: '__new__',
                          child: Text('新建品牌', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == '__new__') {
                          _showNewBrandDialog();
                        } else {
                          setState(() {
                            _formData['brand'] = value ?? '';
                          });
                        }
                      },
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 商品标签
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '商品标签',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 已选标签
                      for (String tag in _formData['tags']) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tag,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _formData['tags'].remove(tag);
                                  });
                                },
                                child: Icon(Icons.close, color: theme.colorScheme.primary, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // 添加标签按钮
                      GestureDetector(
                        onTap: () {
                          // 实现添加标签功能
                          TextEditingController tagController = TextEditingController();
                          final theme = ref.watch(currentThemeProvider);
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: theme.colorScheme.surface,
                              title: Text('添加标签', style: TextStyle(color: theme.colorScheme.onSurface)),
                              content: TextField(
                                controller: tagController,
                                style: TextStyle(color: theme.colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: '请输入标签名称',
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: theme.colorScheme.outline),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty && !_formData['tags'].contains(value.trim())) {
                                    setState(() {
                                      _formData['tags'].add(value.trim());
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (tagController.text.trim().isNotEmpty && !_formData['tags'].contains(tagController.text.trim())) {
                                      setState(() {
                                        _formData['tags'].add(tagController.text.trim());
                                      });
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                  ),
                                  child: const Text('添加'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                            border: Border.all(color: theme.colorScheme.outline, width: 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '添加标签',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 分隔线
          Container(
            height: 1,
            color: theme.colorScheme.outline,
            margin: const EdgeInsets.symmetric(vertical: 20),
          ),
          
          // 预售设置
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '预售商品',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '允许顾客在库存到货前购买',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // 自定义开关
                SizedBox(
                  width: 48,
                  height: 28,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _formData['isPreSale'] = !_formData['isPreSale'];
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _formData['isPreSale'] ? theme.colorScheme.primary : theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _formData['isPreSale'] ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.surface, width: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 上市时间
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上市时间',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _formData['isScheduledRelease'] = false;
                          });
                        },
                        child: Container(
                            height: 80,
                          decoration: BoxDecoration(
                            color: _formData['isScheduledRelease'] ? theme.colorScheme.surfaceVariant : theme.colorScheme.primary.withOpacity(0.1),
                            border: Border.all(
                              color: _formData['isScheduledRelease'] ? theme.colorScheme.outline : theme.colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rocket_launch,
                                color: _formData['isScheduledRelease'] ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '立即上架',
                                style: TextStyle(
                                  color: _formData['isScheduledRelease'] ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _formData['isScheduledRelease'] = true;
                          });
                        },
                        child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: _formData['isScheduledRelease'] ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surfaceVariant,
                            border: Border.all(
                              color: _formData['isScheduledRelease'] ? theme.colorScheme.primary : theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule,
                                color: _formData['isScheduledRelease'] ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '定时上架',
                                style: TextStyle(
                                  color: _formData['isScheduledRelease'] ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_formData['isScheduledRelease']) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _formData['scheduledReleaseTime'] = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                              // 更新控制器文本
                              _scheduledReleaseTimeController.text = '${_formData['scheduledReleaseTime'].year}-${_formData['scheduledReleaseTime'].month.toString().padLeft(2, '0')}-${_formData['scheduledReleaseTime'].day.toString().padLeft(2, '0')} ${_formData['scheduledReleaseTime'].hour.toString().padLeft(2, '0')}:${_formData['scheduledReleaseTime'].minute.toString().padLeft(2, '0')}';
                            });
                          }
                        }
                      },
                      readOnly: true,
                      controller: _scheduledReleaseTimeController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '选择定时时间',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 步骤2：图文视频
  Widget _buildMediaStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品主图
          _buildFormField(
            label: '商品主图',
            isRequired: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主图预览
                if ((_formData['mainImages'] as List).isNotEmpty) ...[
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _formData['mainImages'].length,
                      itemBuilder: (context, index) {
                        final imagePath = _formData['mainImages'][index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2A4532)),
                                  image: DecorationImage(
                                    image: ImageLoaderService.getImageProvider(imagePath),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _formData['mainImages'].removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 上传主图按钮
                ElevatedButton.icon(
                  onPressed: () {
                    _pickImages(5, (images) {
                      setState(() {
                        _formData['mainImages'].addAll(images);
                        // 限制最多5张主图
                        if (_formData['mainImages'].length > 5) {
                          _formData['mainImages'] = _formData['mainImages'].take(5).toList();
                        }
                      });
                    });
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('上传主图'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13ec5b),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '建议上传3-5张，单张不超过5M，推荐尺寸800*800px，支持JPG/PNG/WebP格式',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 商品视频
          _buildFormField(
            label: '商品视频',
            isRequired: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 视频列表和上传区域
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 已上传视频列表
                    if (_videoPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (int i = 0; i < _videoPaths.length; i++)
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF2A4532), style: BorderStyle.solid),
                                color: const Color(0xFF1A2C20),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // 视频播放器
                                            _videoControllers.length > i ? VideoPlayer(_videoControllers[i]) : const SizedBox(),
                                            // 播放/暂停按钮
                                            IconButton(
                                              onPressed: _videoControllers.length > i ? () {
                                                setState(() {
                                                  if (_videoControllers[i].value.isPlaying) {
                                                    _videoControllers[i].pause();
                                                  } else {
                                                    _videoControllers[i].play();
                                                  }
                                                });
                                              } : null,
                                              icon: Icon(
                                                _videoControllers.length > i && _videoControllers[i].value.isPlaying ? 
                                                  Icons.pause_circle : Icons.play_circle,
                                                size: 48,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '视频 ${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        // 删除视频
                                        if (_videoControllers.length > i) {
                                          _videoControllers[i].dispose();
                                          _videoControllers.removeAt(i);
                                        }
                                        _videoPaths.removeAt(i);
                                        
                                        // 更新表单数据
                                        final videos = List<String>.from(_formData['videos'] ?? []);
                                        videos.removeAt(i);
                                        _formData['videos'] = videos;
                                        
                                        // 如果删除的是第一个视频，更新单视频字段
                                        if (i == 0 && videos.isNotEmpty) {
                                          _videoPath = videos[0];
                                          _formData['video'] = videos[0];
                                        } else if (videos.isEmpty) {
                                          _videoPath = '';
                                          _formData['video'] = '';
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.delete),
                                    label: const Text('删除'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                      iconSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // 正在上传的视频
                    if (_selectedVideo != null && _isUploadingVideo)
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A4532), style: BorderStyle.solid),
                          color: const Color(0xFF1A2C20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library, size: 32, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              _selectedVideo?.path.split('/').last ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            // 视频上传进度
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _videoUploadProgress,
                                    backgroundColor: const Color(0xFF2A4532),
                                    color: const Color(0xFF13ec5b),
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 6,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(_videoUploadProgress * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // 上传视频按钮
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.add),
                        label: const Text('添加视频'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13ec5b),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        '支持MP4/MOV/FLV格式，大小不超过500M，时长15秒-5分钟',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 视频描述
                _buildFormField(
                  label: '视频描述',
                  isRequired: false,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _formData['videoDescription'] = value;
                      });
                    },
                    controller: _videoDescriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 100,
                    decoration: _buildInputDecoration(hintText: '描述视频核心内容，如"这款T恤的面料质感和版型展示"'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 商品详情
          _buildFormField(
            label: '商品详情',
            isRequired: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 工具栏
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _insertTable();
                        },
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('插入表格'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2C20),
                          foregroundColor: const Color(0xFF13ec5b),
                          side: const BorderSide(color: Color(0xFF13ec5b)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 富文本编辑器占位符
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A4532)),
                    color: const Color(0xFF1A2C20),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _formData['detail'] = value;
                      });
                    },
                    controller: _productDetailController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintText: '请输入商品详情，支持文字描述、插入图片和视频',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Color(0xFF0D1A12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '支持插入已上传的商品视频，建议详细描述商品特点、材质、使用方法等',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // 富文本功能提示
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('支持文字描述', style: TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFF13ec5b).withOpacity(0.1),
                      labelStyle: TextStyle(color: const Color(0xFF13ec5b), fontSize: 12),
                    ),
                    Chip(
                      label: Text('支持插入图片', style: TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFF13ec5b).withOpacity(0.1),
                      labelStyle: TextStyle(color: const Color(0xFF13ec5b), fontSize: 12),
                    ),
                    Chip(
                      label: Text('支持插入视频', style: TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFF13ec5b).withOpacity(0.1),
                      labelStyle: TextStyle(color: const Color(0xFF13ec5b), fontSize: 12),
                    ),
                    Chip(
                      label: Text('支持表格显示商品参数', style: TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFF13ec5b).withOpacity(0.1),
                      labelStyle: TextStyle(color: const Color(0xFF13ec5b), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 详情图批量上传
          _buildFormField(
            label: '详情图批量上传',
            isRequired: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _pickImages(20, (images) {
                      setState(() {
                        _formData['detailImages'].addAll(images);
                      });
                    });
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('上传详情图'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2C20),
                    foregroundColor: const Color(0xFF13ec5b),
                    side: const BorderSide(color: Color(0xFF13ec5b)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '替代富文本的简化方式，支持拖拽排序，自动适配详情页宽度',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                
                // 详情图预览
                if ((_formData['detailImages'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _formData['detailImages'].length,
                      itemBuilder: (context, index) {
                        final imagePath = _formData['detailImages'][index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF2A4532)),
                                  image: DecorationImage(
                                    image: ImageLoaderService.getImageProvider(imagePath),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _formData['detailImages'].removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 步骤3：规格与库存
  Widget _buildSpecStockStep() {
    debugPrint('=== 开始构建步骤3：规格与库存 ===');
    debugPrint('formData[specType]: ${_formData['specType']}');
    
    try {
      // 确保specs是列表类型
      if (!(_formData['specs'] is List)) {
        debugPrint('specs不是列表类型，初始化为空列表');
        _formData['specs'] = <Map<String, dynamic>>[];
      }
      // 确保skus是列表类型
      if (!(_formData['skus'] is List)) {
        debugPrint('skus不是列表类型，初始化为空列表');
        _formData['skus'] = <Map<String, dynamic>>[];
      }
      
      final specsList = _formData['specs'] as List;
      final skusList = _formData['skus'] as List;
      debugPrint('formData[specs] length: ${specsList.length}');
      debugPrint('formData[skus] length: ${skusList.length}');
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 规格类型
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '规格类型 *',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text('单规格', style: TextStyle(color: Colors.white)),
                        value: 'single',
                        groupValue: _formData['specType'],
                        onChanged: (value) {
                          setState(() {
                            _formData['specType'] = value;
                          });
                        },
                        activeColor: const Color(0xFF13ec5b),
                        tileColor: const Color(0xFF1A2C20),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text('多规格', style: TextStyle(color: Colors.white)),
                        value: 'multiple',
                        groupValue: _formData['specType'],
                        onChanged: (value) {
                          setState(() {
                            _formData['specType'] = value;
                          });
                        },
                        activeColor: const Color(0xFF13ec5b),
                        tileColor: const Color(0xFF1A2C20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 单规格设置
            if (_formData['specType'] == 'single')
              Column(
                children: [
                  // 库存
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A12),
                      border: Border.all(color: const Color(0xFF326744)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _formData['stock'] = int.tryParse(value) ?? 0;
                        });
                      },
                      controller: _stockController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                      labelText: '库存 *',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '请输入商品库存数量',
                      hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      filled: true,
                      fillColor: Color(0xFF0D1A12),
                    )
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 成本价
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A12),
                      border: Border.all(color: const Color(0xFF326744)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          double? costPrice = double.tryParse(value);
                          if (costPrice != null) {
                            costPrice = double.parse(costPrice.toStringAsFixed(3));
                          }
                          _formData['costPrice'] = costPrice ?? 0;
                        });
                      },
                      controller: _costPriceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
                      ],
                      decoration: const InputDecoration(
                      labelText: '成本价 (元)',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '请输入商品成本价，最多保留3位小数',
                      hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      filled: true,
                      fillColor: Color(0xFF0D1A12),
                    )
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 重量
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A12),
                      border: Border.all(color: const Color(0xFF326744)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _formData['weight'] = value;
                        });
                      },
                      controller: _weightController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                      labelText: '重量',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '请输入商品重量',
                      hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      filled: true,
                      fillColor: Color(0xFF0D1A12),
                    )
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 体积
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1A12),
                      border: Border.all(color: const Color(0xFF326744)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _formData['volume'] = value;
                        });
                      },
                      controller: _volumeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                      labelText: '体积',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '请输入商品体积',
                      hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      filled: true,
                      fillColor: Color(0xFF0D1A12),
                    )
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                // 规格项配置
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '规格项配置 *',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    
                    // 规格列表
                    if (specsList.isNotEmpty) ...[
                      Column(
                        children: specsList.asMap().entries.map((entry) {
                          final index = entry.key;
                          final specItem = entry.value;
                          
                          // 确保控制器数量与规格数量一致
                          if (_specNameControllers.length > specsList.length) {
                            for (int i = specsList.length; i < _specNameControllers.length; i++) {
                              _specNameControllers[i].dispose();
                            }
                            _specNameControllers.removeRange(specsList.length, _specNameControllers.length);
                          }
                          if (_specValueControllers.length > specsList.length) {
                            for (int i = specsList.length; i < _specValueControllers.length; i++) {
                              _specValueControllers[i].dispose();
                            }
                            _specValueControllers.removeRange(specsList.length, _specValueControllers.length);
                          }
                          
                          // 确保specs列表项是Map类型
                          final spec = specItem is Map ? specItem as Map<String, dynamic> : {'name': '', 'values': <String>[]};
                          
                          // 确保values是列表类型
                          if (!(spec['values'] is List)) {
                            spec['values'] = <String>[];
                          }
                          
                          // 确保控制器列表长度足够
                          while (_specNameControllers.length <= index) {
                            _specNameControllers.add(TextEditingController());
                          }
                          while (_specValueControllers.length <= index) {
                            _specValueControllers.add(TextEditingController());
                          }
                          
                          // 只在控制器文本为空时更新（避免覆盖用户输入）
                          if (_specNameControllers[index].text != (spec['name'] ?? '')) {
                            _specNameControllers[index].text = spec['name'] ?? '';
                          }
                          final valuesText = ((spec['values'] as List?) ?? []).join(',');
                          if (_specValueControllers[index].text != valuesText) {
                            _specValueControllers[index].text = valuesText;
                          }
                          
                          return Card(
                            color: const Color(0xFF1A2C20),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D1A12),
                                            border: Border.all(color: const Color(0xFF326744)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TextField(
                                            onChanged: (value) {
                                              setState(() {
                                                _formData['specs'][index]['name'] = value;
                                              });
                                            },
                                            controller: _specNameControllers[index],
                                            style: const TextStyle(color: Colors.white),
                                            decoration: const InputDecoration(
                                    labelText: '规格名称',
                                    labelStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                    filled: true,
                                    fillColor: Color(0xFF0D1A12),
                                  ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _formData['specs'].removeAt(index);
                                            if (index < _specNameControllers.length) {
                                              _specNameControllers[index].dispose();
                                              _specNameControllers.removeAt(index);
                                            }
                                            if (index < _specValueControllers.length) {
                                              _specValueControllers[index].dispose();
                                              _specValueControllers.removeAt(index);
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // 规格值
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '规格值（用逗号分隔）',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D1A12),
                                          border: Border.all(color: const Color(0xFF326744)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: TextField(
                                          onChanged: (value) {
                                            setState(() {
                                              _formData['specs'][index]['values'] = value.split(',');
                                            });
                                          },
                                          controller: _specValueControllers[index],
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            hintText: '请输入规格值，用逗号分隔，如：红色,蓝色,黑色',
                                            hintStyle: TextStyle(color: Color(0xFF92c9a4)),
                                            contentPadding: EdgeInsets.all(16),
                                            filled: true,
                                            fillColor: Color(0xFF0D1A12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // 添加规格项
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _formData['specs'].add({
                            'name': '',
                            'values': <String>[],
                          });
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加规格项'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 生成SKU按钮
                    ElevatedButton.icon(
                      onPressed: _generateSkus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('生成SKU'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
                
                // SKU管理
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SKU管理 *',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    
                    // 批量操作按钮
                    if (skusList.isNotEmpty) ...[
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // 批量设置价格
                              _showBatchSetDialog('价格', (value) => _batchSetSkuPrice(value));
                            },
                            icon: const Icon(Icons.price_change),
                            label: const Text('批量设置价格'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13ec5b),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              // 批量设置成本价
                              _showBatchSetDialog('成本价', (value) => _batchSetSkuCostPrice(value));
                            },
                            icon: const Icon(Icons.attach_money),
                            label: const Text('批量设置成本价'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13ec5b),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              // 批量设置库存
                              _showBatchSetDialog('库存', (value) => _batchSetSkuStock(value));
                            },
                            icon: const Icon(Icons.inventory),
                            label: const Text('批量设置库存'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13ec5b),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // SKU表格
                    if (skusList.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFF1A2C20)),
                            dataRowColor: MaterialStateProperty.all(const Color(0xFF1A2C20)),
                            border: TableBorder.all(color: const Color(0xFF2A4532)),
                            columns: [
                              const DataColumn(label: Text('SKU编码', style: TextStyle(color: Colors.white))),
                              const DataColumn(label: Text('规格', style: TextStyle(color: Colors.white))),
                              const DataColumn(label: Text('价格', style: TextStyle(color: Colors.white))),
                              const DataColumn(label: Text('成本价', style: TextStyle(color: Colors.white))),
                              const DataColumn(label: Text('库存', style: TextStyle(color: Colors.white))),
                              const DataColumn(label: Text('操作', style: TextStyle(color: Colors.white))),
                            ],
                            rows: skusList.map((skuItem) {
                              // 确保sku是Map类型
                              final sku = skuItem is Map ? skuItem as Map<String, dynamic> : {'skuCode': '', 'specValues': {}, 'price': 0, 'costPrice': 0, 'stock': 0};
                              
                              // 确保specValues是Map类型
                              if (!(sku['specValues'] is Map)) {
                                sku['specValues'] = <String, String>{};
                              }
                              
                              return DataRow(cells: [
                                DataCell(Text(sku['skuCode'] ?? '', style: const TextStyle(color: Colors.white))),
                                DataCell(Text(
                                  (sku['specValues'] as Map<String, dynamic>).entries.map((e) => '${e.key}: ${e.value}').join(', '),
                                  style: const TextStyle(color: Colors.white),
                                )),
                                DataCell(TextField(
                                  onChanged: (value) {
                                    sku['price'] = int.tryParse(value) ?? 0;
                                  },
                                  controller: TextEditingController(text: (sku['price'] ?? 0).toString()),
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                )),
                                DataCell(TextField(
                                  onChanged: (value) {
                                    sku['costPrice'] = int.tryParse(value) ?? 0;
                                  },
                                  controller: TextEditingController(text: (sku['costPrice'] ?? 0).toString()),
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                )),
                                DataCell(TextField(
                                  onChanged: (value) {
                                    sku['stock'] = int.tryParse(value) ?? 0;
                                  },
                                  controller: TextEditingController(text: (sku['stock'] ?? 0).toString()),
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                )),
                                DataCell(IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _formData['skus'].remove(sku);
                                    });
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A4532), style: BorderStyle.solid),
                          color: const Color(0xFF1A2C20),
                        ),
                        child: const Center(
                          child: Text(
                            '请先添加规格项并生成SKU',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      
      debugPrint('=== 步骤3构建完成 ===');
    } catch (e, stackTrace) {
      debugPrint('构建步骤3时发生错误: $e');
      debugPrint('错误堆栈: $stackTrace');
      // 返回一个简单的错误提示UI
      return Center(
        child: Text(
          '构建规格与库存页面时发生错误: $e',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }
  
  /// 步骤4：价格与优惠
  Widget _buildPriceStep() {
    // 确保discountRules是列表类型
    if (!(_formData['discountRules'] is List)) {
      _formData['discountRules'] = <String>[];
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原价
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A12),
              border: Border.all(color: const Color(0xFF326744)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _formData['originalPrice'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                });
              },
              controller: _originalPriceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
              labelText: '原价',
              labelStyle: TextStyle(color: Colors.grey),
              hintText: '请输入商品原价',
              hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            )
            ),
          ),
          const SizedBox(height: 16),
          
          // 售价
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF193322),
              border: Border.all(color: const Color(0xFF326744)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _formData['price'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                });
              },
              controller: _priceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
              labelText: '售价 *',
              labelStyle: TextStyle(color: Colors.grey),
              hintText: '请输入商品实际售价',
              hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            )
            ),
          ),
          const SizedBox(height: 16),
          
          // 积分
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF193322),
              border: Border.all(color: const Color(0xFF326744)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _formData['points'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                });
              },
              controller: _pointsController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
              labelText: '积分 *',
              labelStyle: TextStyle(color: Colors.grey),
              hintText: '请输入商品可获得的积分',
              hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            )
            ),
          ),
          const SizedBox(height: 16),
          
          // 混合支付（金钱+积分）
          const Text(
            '混合支付',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A12),
              border: Border.all(color: const Color(0xFF326744)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 价格部分
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _formData['hybridPrice'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                        });
                      },
                      controller: _hybridPriceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '价格',
                        labelStyle: TextStyle(color: Colors.grey),
                        hintText: '请输入现金金额',
                        hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Color(0xFF193322),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '+',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  // 积分部分
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _formData['hybridPoints'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                        });
                      },
                      controller: _hybridPointsController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '积分',
                        labelStyle: TextStyle(color: Colors.grey),
                        hintText: '请输入积分数量',
                        hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Color(0xFF193322),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 会员价
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF193322),
              border: Border.all(color: const Color(0xFF326744)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _formData['memberPrice'] = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                });
              },
              controller: _memberPriceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
              labelText: '会员价',
              labelStyle: TextStyle(color: Colors.grey),
              hintText: '请输入会员专享价格',
              hintStyle: TextStyle(color: const Color(0xFF92c9a4), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            )
            ),
          ),
          const SizedBox(height: 16),
          
          // 满减规则
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '满减规则',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  '满100减10',
                  '满200减25',
                  '满500减80',
                  '满1000减200',
                ].map((rule) {
                  final isSelected = (_formData['discountRules'] as List).contains(rule);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          (_formData['discountRules'] as List).remove(rule);
                        } else {
                          (_formData['discountRules'] as List).add(rule);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF1A2C20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF2A4532),
                        ),
                      ),
                      child: Text(
                        rule,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 参与活动
          Row(
            children: [
              const Text(
                '参与活动',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Switch(
                value: _formData['participateInActivity'],
                onChanged: (value) {
                  setState(() {
                    _formData['participateInActivity'] = value;
                  });
                },
                activeColor: const Color(0xFF13ec5b),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 支付方式
          const Text(
            '支付方式',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              // 积分支付
              Row(
                children: [
                  const Text(
                    '积分支付',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  Switch(
                    value: _formData['supportPointsPayment'],
                    onChanged: (value) {
                      setState(() {
                        _formData['supportPointsPayment'] = value;
                      });
                    },
                    activeColor: const Color(0xFF13ec5b),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 现金支付
              Row(
                children: [
                  const Text(
                    '现金支付',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  Switch(
                    value: _formData['supportCashPayment'],
                    onChanged: (value) {
                      setState(() {
                        _formData['supportCashPayment'] = value;
                      });
                    },
                    activeColor: const Color(0xFF13ec5b),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 混合支付
              Row(
                children: [
                  const Text(
                    '混合支付',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const Spacer(),
                  Switch(
                    value: _formData['supportHybridPayment'],
                    onChanged: (value) {
                      setState(() {
                        _formData['supportHybridPayment'] = value;
                      });
                    },
                    activeColor: const Color(0xFF13ec5b),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          

        ],
      ),
    );
  }
  
  /// 步骤5：物流服务
  Widget _buildShippingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 运费模板
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '运费模板 *',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A4532)),
                  color: const Color(0xFF1A2C20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _formData['shippingTemplateId'],
                    hint: const Text(
                      '选择运费模板',
                      style: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1A2C20),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                    items: [
                      // 简化处理，实际应从数据库获取
                      DropdownMenuItem<int?>(
                        value: 1,
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            const Text('全场包邮'),
                          ],
                        ),
                      ),
                      DropdownMenuItem<int?>(
                        value: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            const Text('按重量计费'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _formData['shippingTemplateId'] = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 发货时效
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '发货时效 *',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  '24',
                  '48',
                  '168',
                ].map((time) {
                  final isSelected = _formData['shippingTime'] == time;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _formData['shippingTime'] = time;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF1A2C20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF13ec5b) : const Color(0xFF2A4532),
                        ),
                      ),
                      child: Text(
                        '$time小时内发货',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 发货地址
          TextField(
            onChanged: (value) {
              setState(() {
                _formData['shippingAddress'] = value;
              });
            },
            controller: _shippingAddressController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '发货地址 *',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2A4532)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13ec5b)),
              ),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            ),
          ),
          const SizedBox(height: 16),
          
          // 退换货规则
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '退换货规则 *',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A4532)),
                  color: const Color(0xFF1A2C20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _formData['returnPolicy'],
                    hint: const Text(
                      '选择退换货规则',
                      style: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1A2C20),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'seven_days',
                        child: const Text('七天无理由退换'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'custom_no_return',
                        child: const Text('定制商品不支持退换'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'after_sale_service',
                        child: const Text('联系客服处理'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _formData['returnPolicy'] = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 步骤6：其他设置
  Widget _buildOtherStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品排序权重
          TextField(
            onChanged: (value) {
              setState(() {
                _formData['sortWeight'] = int.tryParse(value) ?? 0;
              });
            },
            controller: _sortWeightController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '商品排序权重',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2A4532)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13ec5b)),
              ),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            ),
          ),
          const SizedBox(height: 16),
          
          // 限购设置
          Row(
            children: [
              const Text(
                '限购设置',
                style: TextStyle(color: Colors.white),
              ),
              const Spacer(),
              Switch(
                value: _formData['isLimitedPurchase'],
                onChanged: (value) {
                  setState(() {
                    _formData['isLimitedPurchase'] = value;
                  });
                },
                activeColor: const Color(0xFF13ec5b),
              ),
            ],
          ),
          if (_formData['isLimitedPurchase']) ...[
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  _formData['limitQuantity'] = int.tryParse(value) ?? 1;
                });
              },
              controller: _limitQuantityController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每人限购数量',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2A4532)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF13ec5b)),
                ),
                filled: true,
                fillColor: Color(0xFF0D1A12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          
          // 内部备注
          TextField(
            onChanged: (value) {
              setState(() {
                _formData['internalNote'] = value;
              });
            },
            controller: _internalNoteController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '内部备注',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2A4532)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF13ec5b)),
              ),
              filled: true,
              fillColor: Color(0xFF0D1A12),
            ),
          ),
          const SizedBox(height: 16),
          
          // SEO设置
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SEO设置',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) {
                  setState(() {
                    _formData['seoTitle'] = value;
                  });
                },
                controller: _seoTitleController,
                style: const TextStyle(color: Colors.white),
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'SEO标题',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2A4532)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF13ec5b)),
                  ),
                  filled: true,
                  fillColor: Color(0xFF0D1A12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  setState(() {
                    _formData['seoKeywords'] = value;
                  });
                },
                controller: _seoKeywordsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'SEO关键词',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2A4532)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF13ec5b)),
                  ),
                  hintText: '用逗号分隔多个关键词',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF0D1A12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建表单字段容器
  Widget _buildFormField({required String label, required bool isRequired, required Widget child}) {
    final theme = ref.watch(currentThemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// 构建输入框装饰
  InputDecoration _buildInputDecoration({String? hintText}) {
    final theme = ref.watch(currentThemeProvider);
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.colorScheme.error),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant,
    );
  }

  /// 显示批量设置对话框
  void _showBatchSetDialog(String fieldName, void Function(int) onConfirm) {
    final TextEditingController controller = TextEditingController();
    final theme = ref.watch(currentThemeProvider);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('批量设置$fieldName', style: TextStyle(color: theme.colorScheme.onSurface)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.colorScheme.onSurface),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '$fieldName',
              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant,
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
              onPressed: () {
                final value = int.tryParse(controller.text) ?? 0;
                onConfirm(value);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('确定'),
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
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 主内容区域 - 使用Column布局
          Column(
            children: [
              // 顶部导航栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 关闭按钮
                      GestureDetector(
                        onTap: () {
                          _saveAsDraftToDatabase();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 24),
                        ),
                      ),
                    // 标题
                    Text(
                      widget.product != null ? '编辑商品' : '新增商品',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.015,
                      ),
                    ),
                    // 帮助按钮
                    GestureDetector(
                      onTap: () {
                        // TODO: 实现帮助功能
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '帮助',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 进度指示器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // 步骤信息
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '步骤 ${_currentStep + 1}/6',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _steps[_currentStep]['title']!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 进度条
                    Row(
                      children: List.generate(6, (index) {
                        final isActive = index <= _currentStep;
                        return Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              
              // 自动保存提示
              if (_isAutoSaving) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    'Saving draft...',
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                  ),
                ),
              ],
              
              // 主内容区域
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return _buildStepContent(stepIndex: index);
                  },
                ),
              ),
              
              // 底部操作栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
                ),
                child: Row(
                  children: [
                    // 返回上一步按钮
                    if (_currentStep > 0) ...[
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                            _pageController.jumpToPage(_currentStep);
                          });
                        },
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back, size: 18),
                            const SizedBox(width: 4),
                            Text('上一步'),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          side: BorderSide(color: theme.colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // 保存草稿按钮
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _saveDraft();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('草稿已保存')),
                          );
                        },
                        child: const Text('保存草稿'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 下一步/提交按钮
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_currentStep < 5 ? '下一步' : '提交'),
                            if (_currentStep < 5) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 提交中遮罩 - 作为Stack的子部件，覆盖在所有内容之上
          if (_isSubmitting) ...[
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      '正在提交商品...',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}