import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class MerchantManagementPage extends ConsumerStatefulWidget {
  const MerchantManagementPage({super.key});

  @override
  ConsumerState<MerchantManagementPage> createState() => _MerchantManagementPageState();
}

class _MerchantManagementPageState extends ConsumerState<MerchantManagementPage> with SingleTickerProviderStateMixin {
  List<Merchant> _merchants = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = ProductDatabaseService();
      _merchants = await databaseService.getAllMerchants();
      
      if (_merchants.isEmpty) {
        final mockMerchants = <Merchant>[
          Merchant(
            id: 1,
            userId: 'user1',
            name: '时光良品旗舰店',
            description: '专注于时光生活好物，为您提供优质的文创产品',
            logo: null,
            phone: '400-888-8888',
            email: 'merchant1@example.com',
            address: '深圳市南山区科技园南区',
            status: 'active',
            rating: 4.8,
            totalSales: 1234,
            createdAt: DateTime.now().subtract(const Duration(days: 90)),
            updatedAt: DateTime.now()),
          Merchant(
            id: 2,
            userId: 'user2',
            name: '文创精品店',
            description: '创意文化产品，让生活更有仪式感',
            logo: null,
            phone: '400-999-9999',
            email: 'merchant2@example.com',
            address: '北京市朝阳区三里屯',
            status: 'active',
            rating: 4.6,
            totalSales: 567,
            createdAt: DateTime.now().subtract(const Duration(days: 60)),
            updatedAt: DateTime.now()),
          Merchant(
            id: 3,
            userId: 'user3',
            name: '时光书店',
            description: '精选好书，陪伴您的阅读时光',
            logo: null,
            phone: '400-777-7777',
            email: 'merchant3@example.com',
            address: '杭州市西湖区文三路',
            status: 'inactive',
            rating: 4.9,
            totalSales: 892,
            createdAt: DateTime.now().subtract(const Duration(days: 120)),
            updatedAt: DateTime.now().subtract(const Duration(days: 7))),
          Merchant(
            id: 4,
            userId: 'user4',
            name: '手工艺术馆',
            description: '匠心手作，传递温暖',
            logo: null,
            phone: '400-666-6666',
            email: 'merchant4@example.com',
            address: '成都市锦江区太古里',
            status: 'active',
            rating: 4.7,
            totalSales: 345,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
            updatedAt: DateTime.now()),
        ];
        
        for (var merchant in mockMerchants) {
          await databaseService.insertMerchant(merchant);
        }
        _merchants = mockMerchants;
      }
    } catch (e) {
      debugPrint('加载商家数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Merchant> get _filteredMerchants {
    var filtered = _merchants;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) => 
        m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        m.description?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
      ).toList();
    }
    
    if (_selectedFilter != 'all') {
      filtered = filtered.where((m) => m.status == _selectedFilter).toList();
    }
    
    return filtered;
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
        title: Text('商家管理', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.colorScheme.primary),
            onPressed: () => _showAddMerchantDialog(theme),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: '商家列表'),
            Tab(text: '商家统计'),
          ],
        ),
      ),
      body: _isLoading ? _buildLoadingState(theme) : TabBarView(
        controller: _tabController,
        children: [
          _buildMerchantsList(theme),
          _buildMerchantsStats(theme),
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
            '加载商家数据中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantsList(ThemeData theme) {
    return Column(
      children: [
        _buildSearchBar(theme),
        _buildFilterChips(theme),
        Expanded(
          child: _filteredMerchants.isEmpty 
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredMerchants.length,
                  itemBuilder: (context, index) {
                    final merchant = _filteredMerchants[index];
                    return _buildMerchantItem(merchant, theme);
                  },
                ),
        ),
      ],
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
          hintText: '搜索商家名称或描述...',
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

  Widget _buildFilterChips(ThemeData theme) {
    final filters = [
      {'label': '全部', 'value': 'all'},
      {'label': '营业中', 'value': 'active'},
      {'label': '已歇业', 'value': 'inactive'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['value'] as String;
                  });
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                checkmarkColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                backgroundColor: theme.colorScheme.surfaceVariant,
                side: BorderSide.none,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront,
            color: theme.colorScheme.onSurfaceVariant,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无商家',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantItem(Merchant merchant, ThemeData theme) {
    final isActive = merchant.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${merchant.rating}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '销量: ${merchant.totalSales}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.outlineVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? '营业中' : '已歇业',
                    style: TextStyle(
                      color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              merchant.description ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  merchant.phone ?? '',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    merchant.address ?? '',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _toggleMerchantStatus(merchant);
                  },
                  icon: Icon(isActive ? Icons.pause : Icons.play_arrow),
                  label: Text(isActive ? '暂停营业' : '恢复营业'),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _showMerchantDetails(merchant, theme);
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('查看详情'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _showMerchantProducts(merchant, theme);
                  },
                  icon: const Icon(Icons.shopping_bag),
                  label: const Text('商品管理'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantsStats(ThemeData theme) {
    final activeCount = _merchants.where((m) => m.status == 'active').length;
    final inactiveCount = _merchants.where((m) => m.status == 'inactive').length;
    final totalSales = _merchants.fold<int>(0, (sum, m) => sum + m.totalSales);
    final avgRating = _merchants.isNotEmpty 
        ? _merchants.fold<double>(0, (sum, m) => sum + m.rating) / _merchants.length 
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据概览',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStatCard(
                theme,
                Icons.storefront,
                '营业商家',
                '$activeCount',
                theme.colorScheme.primary,
              ),
              _buildStatCard(
                theme,
                Icons.close_sharp,
                '歇业商家',
                '$inactiveCount',
                theme.colorScheme.error,
              ),
              _buildStatCard(
                theme,
                Icons.trending_up,
                '总销量',
                '$totalSales',
                Colors.green,
              ),
              _buildStatCard(
                theme,
                Icons.star,
                '平均评分',
                avgRating.toStringAsFixed(1),
                Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '商家排行',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...() {
            final sortedMerchants = [..._merchants];
            sortedMerchants.sort((a, b) => b.totalSales.compareTo(a.totalSales));
            final topMerchants = sortedMerchants.take(5).toList();
            return topMerchants.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final merchant = entry.value;
              return _buildRankingItem(theme, index, merchant);
            }).toList();
          }(),
          
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingItem(ThemeData theme, int rank, Merchant merchant) {
    Color rankColor;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '销量: ${merchant.totalSales} | 评分: ${merchant.rating}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMerchantDetails(Merchant merchant, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('商家详情', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('商家名称', merchant.name, theme),
                _buildDetailItem('描述', merchant.description ?? '暂无描述', theme),
                _buildDetailItem('联系电话', merchant.phone ?? '暂无', theme),
                _buildDetailItem('邮箱', merchant.email ?? '暂无', theme),
                _buildDetailItem('地址', merchant.address ?? '暂无', theme),
                _buildDetailItem('评分', '${merchant.rating}', theme),
                _buildDetailItem('总销量', '${merchant.totalSales}', theme),
                _buildDetailItem('状态', merchant.status == 'active' ? '营业中' : '已歇业', theme),
                _buildDetailItem('创建时间', merchant.createdAt.toString().substring(0, 19), theme),
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

  void _showMerchantProducts(Merchant merchant, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('${merchant.name} - 商品管理', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '该功能将在后续版本中实现',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _showAddMerchantDialog(ThemeData theme) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('添加商家', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '商家名称',
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
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: '商家描述',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: '联系电话',
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
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: '邮箱',
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
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: '地址',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
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
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('添加成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
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
  }

  Future<void> _toggleMerchantStatus(Merchant merchant) async {
    final newStatus = merchant.status == 'active' ? 'inactive' : 'active';
    
    setState(() {
      final index = _merchants.indexWhere((m) => m.id == merchant.id);
      if (index != -1) {
        _merchants[index] = Merchant(
          id: merchant.id,
          userId: merchant.userId,
          name: merchant.name,
          description: merchant.description,
          logo: merchant.logo,
          phone: merchant.phone,
          email: merchant.email,
          address: merchant.address,
          status: newStatus,
          rating: merchant.rating,
          totalSales: merchant.totalSales,
          createdAt: merchant.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'active' ? '商家已恢复营业' : '商家已暂停营业',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
