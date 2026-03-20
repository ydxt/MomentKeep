import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class StockRecordsPage extends ConsumerStatefulWidget {
  const StockRecordsPage({super.key});

  @override
  ConsumerState<StockRecordsPage> createState() => _StockRecordsPageState();
}

class _StockRecordsPageState extends ConsumerState<StockRecordsPage> with SingleTickerProviderStateMixin {
  List<StockRecord> _stockRecords = [];
  List<StarProduct> _products = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _searchQuery = '';
  int _warningThreshold = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStockRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStockRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = ProductDatabaseService();
      _stockRecords = await databaseService.getAllStockRecords();
      
      if (_stockRecords.isEmpty) {
        final mockRecords = [
          StockRecord(
            id: 1,
            productId: 1,
            skuId: 1,
            type: 'in',
            quantity: 100,
            stockBefore: 0,
            stockAfter: 100,
            relatedId: 'INIT20260401001',
            remark: '初始库存入库',
            operatorId: 'admin',
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
          StockRecord(
            id: 2,
            productId: 1,
            skuId: 1,
            type: 'out',
            quantity: 10,
            stockBefore: 100,
            stockAfter: 90,
            relatedId: 'ORD20260405001',
            remark: '订单出库',
            operatorId: 'system',
            createdAt: DateTime.now().subtract(const Duration(days: 25)),
          ),
          StockRecord(
            id: 3,
            productId: 2,
            skuId: 2,
            type: 'in',
            quantity: 200,
            stockBefore: 50,
            stockAfter: 250,
            relatedId: 'PURCH20260410001',
            remark: '采购入库',
            operatorId: 'admin',
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
          ),
          StockRecord(
            id: 4,
            productId: 1,
            skuId: 1,
            type: 'out',
            quantity: 5,
            stockBefore: 90,
            stockAfter: 85,
            relatedId: 'ORD20260412002',
            remark: '订单出库',
            operatorId: 'system',
            createdAt: DateTime.now().subtract(const Duration(days: 18)),
          ),
          StockRecord(
            id: 5,
            productId: 3,
            skuId: 3,
            type: 'in',
            quantity: 50,
            stockBefore: 0,
            stockAfter: 50,
            relatedId: 'PURCH20260415002',
            remark: '新品入库',
            operatorId: 'admin',
            createdAt: DateTime.now().subtract(const Duration(days: 15)),
          ),
          StockRecord(
            id: 6,
            productId: 2,
            skuId: 2,
            type: 'adjust',
            quantity: -5,
            stockBefore: 250,
            stockAfter: 245,
            relatedId: 'ADJUST20260418001',
            remark: '库存盘点调整',
            operatorId: 'admin',
            createdAt: DateTime.now().subtract(const Duration(days: 12)),
          ),
          StockRecord(
            id: 7,
            productId: 1,
            skuId: 1,
            type: 'out',
            quantity: 3,
            stockBefore: 85,
            stockAfter: 82,
            relatedId: 'ORD20260420003',
            remark: '订单出库',
            operatorId: 'system',
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          StockRecord(
            id: 8,
            productId: 3,
            skuId: 3,
            type: 'in',
            quantity: 30,
            stockBefore: 50,
            stockAfter: 80,
            relatedId: 'PURCH20260425003',
            remark: '补货入库',
            operatorId: 'admin',
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ];
        
        for (var record in mockRecords) {
          await databaseService.insertStockRecord(record);
        }
        _stockRecords = mockRecords;
      }
      
      _loadMockProducts();
    } catch (e) {
      debugPrint('加载库存记录失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _loadMockProducts() {
    _products = [
      StarProduct(
        id: 1,
        name: '精美茶具套装',
        description: '高品质陶瓷茶具，包含茶壶和4个茶杯',
        image: 'https://picsum.photos/seed/product1/400/400',
        mainImages: ['https://picsum.photos/seed/product1/400/400'],
        productCode: 'PROD001',
        points: 1000,
        costPrice: 50,
        stock: 45,
        categoryId: 1,
        isActive: true,
        isDeleted: false,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      StarProduct(
        id: 2,
        name: '精品咖啡礼盒',
        description: '精选咖啡豆，送礼佳品',
        image: 'https://picsum.photos/seed/product2/400/400',
        mainImages: ['https://picsum.photos/seed/product2/400/400'],
        productCode: 'PROD002',
        points: 500,
        costPrice: 30,
        stock: 200,
        categoryId: 1,
        isActive: true,
        isDeleted: false,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now(),
      ),
      StarProduct(
        id: 3,
        name: '手工笔记本',
        description: '精美手工笔记本，记录美好时光',
        image: 'https://picsum.photos/seed/product3/400/400',
        mainImages: ['https://picsum.photos/seed/product3/400/400'],
        productCode: 'PROD003',
        points: 200,
        costPrice: 15,
        stock: 25,
        categoryId: 2,
        isActive: true,
        isDeleted: false,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now(),
      ),
      StarProduct(
        id: 4,
        name: '智能保温杯',
        description: '温度显示，智能提醒喝水',
        image: 'https://picsum.photos/seed/product4/400/400',
        mainImages: ['https://picsum.photos/seed/product4/400/400'],
        productCode: 'PROD004',
        points: 800,
        costPrice: 45,
        stock: 10,
        categoryId: 1,
        isActive: true,
        isDeleted: false,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
      ),
      StarProduct(
        id: 5,
        name: '创意台灯',
        description: '护眼LED台灯，可调亮度',
        image: 'https://picsum.photos/seed/product5/400/400',
        mainImages: ['https://picsum.photos/seed/product5/400/400'],
        productCode: 'PROD005',
        points: 1500,
        costPrice: 80,
        stock: 150,
        categoryId: 3,
        isActive: true,
        isDeleted: false,
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: DateTime.now(),
      ),
    ];
  }
  
  List<StarProduct> _getWarningProducts() {
    return _products.where((product) => product.stock < _warningThreshold).toList();
  }

  List<StockRecord> _getFilteredRecords(String type) {
    var records = _stockRecords;
    
    if (type != 'all') {
      records = records.where((r) => r.type == type).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      records = records.where((r) => 
        r.productId.toString().contains(_searchQuery) ||
        (r.relatedId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (r.remark?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    return records;
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
        title: Text('库存记录', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.colorScheme.primary),
            onPressed: () => _showAddStockDialog(theme),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '入库'),
            Tab(text: '出库'),
            Tab(text: '调整'),
            Tab(text: '库存预警'),
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
                _buildStockList('all', theme),
                _buildStockList('in', theme),
                _buildStockList('out', theme),
                _buildStockList('adjust', theme),
                _buildStockWarningList(theme),
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
            '加载库存记录中...',
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索商品ID、关联单号或备注...',
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
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.insert_chart_outlined, color: theme.colorScheme.primary),
            onPressed: () => _showStatisticsDialog(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(String type, ThemeData theme) {
    final records = _getFilteredRecords(type);
    
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2,
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无库存记录',
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
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildStockItem(record, theme);
      },
    );
  }

  Widget _buildStockItem(StockRecord record, ThemeData theme) {
    final typeInfo = _getTypeInfo(record.type);

    return GestureDetector(
      onTap: () {
        _showStockDetail(record, theme);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: record.type == 'in' ? Colors.green.withOpacity(0.5) : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (typeInfo['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      typeInfo['icon'] as IconData,
                      color: typeInfo['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '商品ID: ${record.productId}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU ID: ${record.skuId ?? "无"}',
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
                      color: (typeInfo['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      typeInfo['text'] as String,
                      style: TextStyle(
                        color: typeInfo['color'] as Color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '变动数量',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.type == 'in' ? '+' : ''}${record.quantity}',
                        style: TextStyle(
                          color: typeInfo['color'] as Color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '库存变化',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.stockBefore} → ${record.stockAfter}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (record.relatedId != null && record.relatedId!.isNotEmpty)
                    Expanded(
                      child: Text(
                        '关联单号: ${record.relatedId}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (record.remark != null && record.remark!.isNotEmpty)
                Text(
                  '备注: ${record.remark}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '操作人: ${record.operatorId}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    record.createdAt.toString().substring(0, 16),
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
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(String type) {
    switch (type) {
      case 'in':
        return {'text': '入库', 'color': Colors.green, 'icon': Icons.add_circle};
      case 'out':
        return {'text': '出库', 'color': Theme.of(context).colorScheme.error, 'icon': Icons.remove_circle};
      case 'adjust':
        return {'text': '调整', 'color': Colors.orange, 'icon': Icons.swap_horiz};
      default:
        return {'text': '未知', 'color': Colors.grey, 'icon': Icons.help};
    }
  }

  void _showStockDetail(StockRecord record, ThemeData theme) {
    final typeInfo = _getTypeInfo(record.type);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('库存详情', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('商品ID', '${record.productId}', theme),
                _buildDetailItem('SKU ID', record.skuId?.toString() ?? '无', theme),
                _buildDetailItem('变动类型', typeInfo['text'] as String, theme),
                _buildDetailItem('变动数量', '${record.type == 'in' ? '+' : ''}${record.quantity}', theme),
                _buildDetailItem('变动前库存', '${record.stockBefore}', theme),
                _buildDetailItem('变动后库存', '${record.stockAfter}', theme),
                const Divider(height: 24),
                _buildDetailItem('关联单号', record.relatedId ?? '无', theme),
                _buildDetailItem('备注', record.remark ?? '无', theme),
                _buildDetailItem('操作人ID', record.operatorId, theme),
                _buildDetailItem('操作时间', record.createdAt.toString().substring(0, 19), theme),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(ThemeData theme) {
    final productIdController = TextEditingController();
    final skuIdController = TextEditingController();
    final quantityController = TextEditingController();
    final relatedIdController = TextEditingController();
    final remarkController = TextEditingController();
    String selectedType = 'in';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.background,
              title: Text('添加库存记录', style: TextStyle(color: theme.colorScheme.onBackground)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: '变动类型',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('入库')),
                        DropdownMenuItem(value: 'out', child: Text('出库')),
                        DropdownMenuItem(value: 'adjust', child: Text('调整')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: productIdController,
                      decoration: InputDecoration(
                        labelText: '商品ID',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: skuIdController,
                      decoration: InputDecoration(
                        labelText: 'SKU ID (可选)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: '数量',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: relatedIdController,
                      decoration: InputDecoration(
                        labelText: '关联单号 (可选)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarkController,
                      decoration: InputDecoration(
                        labelText: '备注 (可选)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 2,
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
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('库存记录添加成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text('添加', style: TextStyle(color: theme.colorScheme.primary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatisticsDialog(ThemeData theme) {
    final totalInbound = _stockRecords.where((r) => r.type == 'in').fold<int>(0, (sum, r) => sum + r.quantity.abs());
    final totalOutbound = _stockRecords.where((r) => r.type == 'out').fold<int>(0, (sum, r) => sum + r.quantity.abs());
    final totalAdjustment = _stockRecords.where((r) => r.type == 'adjust').fold<int>(0, (sum, r) => sum + r.quantity.abs());
    final inboundCount = _stockRecords.where((r) => r.type == 'in').length;
    final outboundCount = _stockRecords.where((r) => r.type == 'out').length;
    final adjustmentCount = _stockRecords.where((r) => r.type == 'adjust').length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('库存统计', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildStatCard(theme, Icons.add_circle, '入库', '$totalInbound', Colors.green, '$inboundCount笔'),
                    _buildStatCard(theme, Icons.remove_circle, '出库', '$totalOutbound', theme.colorScheme.error, '$outboundCount笔'),
                    _buildStatCard(theme, Icons.swap_horiz, '调整', '$totalAdjustment', Colors.orange, '$adjustmentCount笔'),
                    _buildStatCard(theme, Icons.inventory_2, '净变动', '${totalInbound - totalOutbound}', theme.colorScheme.primary, ''),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(ThemeData theme, IconData icon, String label, String value, Color color, String subValue) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          if (subValue.isNotEmpty)
            Text(
              subValue,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStockWarningList(ThemeData theme) {
    final warningProducts = _getWarningProducts();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    '预警阈值: $_warningThreshold件',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showThresholdDialog(theme),
                icon: Icon(Icons.settings, color: theme.colorScheme.primary),
                label: Text('设置阈值', style: TextStyle(color: theme.colorScheme.primary)),
              ),
            ],
          ),
        ),
        Expanded(
          child: warningProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '所有商品库存充足',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: warningProducts.length,
                  itemBuilder: (context, index) {
                    return _buildWarningProductItem(warningProducts[index], theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWarningProductItem(StarProduct product, ThemeData theme) {
    Color warningColor = product.stock < 20 ? theme.colorScheme.error : Colors.orange;
    String warningLevel = product.stock < 20 ? '紧急缺货' : '库存偏低';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warningColor.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(product.image),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.productCode,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    warningLevel,
                    style: TextStyle(
                      color: warningColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前库存',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.stock} 件',
                      style: TextStyle(
                        color: warningColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '建议补货',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_warningThreshold * 2 - product.stock}+ 件',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _quickRestock(product, theme),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('快速补货'),
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

  void _showThresholdDialog(ThemeData theme) {
    final controller = TextEditingController(text: _warningThreshold.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('设置库存预警阈值', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '预警阈值（件）',
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
                final newThreshold = int.tryParse(controller.text);
                if (newThreshold != null && newThreshold > 0) {
                  setState(() {
                    _warningThreshold = newThreshold;
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('确定', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _quickRestock(StarProduct product, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        final quantityController = TextEditingController(text: '100');
        
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('快速补货 - ${product.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '补货数量',
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('补货申请已提交', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text('确认补货', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }
}
