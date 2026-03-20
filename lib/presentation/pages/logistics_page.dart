import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class LogisticsPage extends ConsumerStatefulWidget {
  const LogisticsPage({super.key});

  @override
  ConsumerState<LogisticsPage> createState() => _LogisticsPageState();
}

class _LogisticsPageState extends ConsumerState<LogisticsPage> with SingleTickerProviderStateMixin {
  List<LogisticsCompany> _logisticsCompanies = [];
  List<LogisticsTrack> _logisticsTracks = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _selectedFilter = '全部';
  final List<String> _filters = ['全部', '启用中', '已停用'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLogisticsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogisticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = ProductDatabaseService();
      _logisticsCompanies = await databaseService.getAllLogisticsCompanies();
      
      if (_logisticsCompanies.isEmpty) {
        final mockCompanies = <LogisticsCompany>[
          LogisticsCompany(
            id: 1,
            name: '顺丰快递',
            code: 'SF',
            phone: '95338',
            website: 'https://www.sf-express.com',
            isActive: true,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
            updatedAt: DateTime.now()),
          LogisticsCompany(
            id: 2,
            name: '圆通速递',
            code: 'YTO',
            phone: '95554',
            website: 'https://www.yto.net.cn',
            isActive: true,
            createdAt: DateTime.now().subtract(const Duration(days: 25)),
            updatedAt: DateTime.now()),
          LogisticsCompany(
            id: 3,
            name: '中通快递',
            code: 'ZTO',
            phone: '95311',
            website: 'https://www.zto.com',
            isActive: true,
            createdAt: DateTime.now().subtract(const Duration(days: 20)),
            updatedAt: DateTime.now()),
          LogisticsCompany(
            id: 4,
            name: '韵达快递',
            code: 'YD',
            phone: '95546',
            website: 'https://www.yundaex.com',
            isActive: false,
            createdAt: DateTime.now().subtract(const Duration(days: 15)),
            updatedAt: DateTime.now()),
        ];
        
        for (var company in mockCompanies) {
          await databaseService.insertLogisticsCompany(company);
        }
        _logisticsCompanies = mockCompanies;
      }
    } catch (e) {
      debugPrint('加载物流数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<LogisticsCompany> get _filteredCompanies {
    if (_selectedFilter == '全部') {
      return _logisticsCompanies;
    } else if (_selectedFilter == '启用中') {
      return _logisticsCompanies.where((c) => c.isActive).toList();
    } else {
      return _logisticsCompanies.where((c) => !c.isActive).toList();
    }
  }

  Future<void> _toggleCompanyStatus(LogisticsCompany company) async {
    try {
      final databaseService = ProductDatabaseService();
      final updatedCompany = LogisticsCompany(
        id: company.id,
        name: company.name,
        code: company.code,
        website: company.website,
        phone: company.phone,
        isActive: !company.isActive,
        sortOrder: company.sortOrder,
        createdAt: company.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await databaseService.updateLogisticsCompany(company.id!, updatedCompany);
      await _loadLogisticsData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(company.isActive ? '物流公司已停用' : '物流公司已启用'),
            backgroundColor: ref.read(currentThemeProvider).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddCompanyDialog() {
    final theme = ref.read(currentThemeProvider);
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('添加物流公司', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '公司名称',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: '公司编码',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: '联系电话',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: websiteController,
                  decoration: InputDecoration(
                    labelText: '官方网站',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
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
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                  try {
                    final databaseService = ProductDatabaseService();
                    final newCompany = LogisticsCompany(
                      name: nameController.text,
                      code: codeController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                      website: websiteController.text.isNotEmpty ? websiteController.text : null,
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await databaseService.insertLogisticsCompany(newCompany);
                    await _loadLogisticsData();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('物流公司添加成功'),
                          backgroundColor: theme.colorScheme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('添加失败: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _showTrackingDialog(LogisticsCompany company) {
    final theme = ref.read(currentThemeProvider);
    final trackingController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Row(
            children: [
              Icon(Icons.local_shipping, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('物流追踪 - ${company.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: trackingController,
                decoration: InputDecoration(
                  hintText: '请输入运单号',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.confirmation_number, color: theme.colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showTrackingResult(company, trackingController.text);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('查询物流'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        );
      },
    );
  }

  void _showTrackingResult(LogisticsCompany company, String trackingNumber) {
    final theme = ref.read(currentThemeProvider);
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Row(
            children: [
              Icon(Icons.local_shipping, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('物流信息 - $trackingNumber', style: TextStyle(color: theme.colorScheme.onBackground)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '运输中',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '预计 2 天后送达',
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
                ),
                const SizedBox(height: 24),
                Text(
                  '物流轨迹',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildTrackingSteps(theme),
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

  List<Widget> _buildTrackingSteps(ThemeData theme) {
    final steps = [
      {
        'time': DateTime.now().subtract(const Duration(hours: 2)),
        'location': '深圳市南山区',
        'description': '快件已从【深圳转运中心】发出，正在运往下一站',
        'isCurrent': false,
      },
      {
        'time': DateTime.now().subtract(const Duration(hours: 6)),
        'location': '深圳市',
        'description': '快件已到达【深圳转运中心】',
        'isCurrent': false,
      },
      {
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'location': '深圳市南山区',
        'description': '快件已揽收',
        'isCurrent': true,
      },
    ];

    return steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      final isLast = index == steps.length - 1;
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: step['isCurrent'] as bool ? theme.colorScheme.primary : theme.colorScheme.outline,
                  shape: BoxShape.circle,
                ),
                child: step['isCurrent'] as bool
                    ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 12)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: theme.colorScheme.outline,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['description'] as String,
                    style: TextStyle(
                      color: step['isCurrent'] as bool 
                          ? theme.colorScheme.onSurface 
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: step['isCurrent'] as bool ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['location'] as String,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(step['time'] as DateTime),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showCompanyDetail(LogisticsCompany company) {
    final theme = ref.read(currentThemeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('物流公司详情', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('公司名称', company.name, theme),
                _buildDetailItem('公司编码', company.code, theme),
                if (company.phone != null)
                  _buildDetailItem('联系电话', company.phone!, theme),
                if (company.website != null)
                  _buildDetailItem('官方网站', company.website!, theme),
                _buildDetailItem('状态', company.isActive ? '启用中' : '已停用', theme),
                _buildDetailItem('创建时间', company.createdAt.toString().substring(0, 19), theme),
                _buildDetailItem('更新时间', company.updatedAt.toString().substring(0, 19), theme),
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
      padding: const EdgeInsets.only(bottom: 16),
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
        title: Text('物流管理', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.colorScheme.primary),
            onPressed: _showAddCompanyDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: '物流公司'),
            Tab(text: '物流追踪'),
          ],
        ),
      ),
      body: _isLoading 
          ? _buildLoadingState(theme) 
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCompaniesList(theme),
                _buildTrackingPage(theme),
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
            '加载物流数据中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompaniesList(ThemeData theme) {
    return Column(
      children: [
        Container(
          height: 50,
          margin: const EdgeInsets.all(16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: EdgeInsets.only(right: index < _filters.length - 1 ? 8 : 0),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _filteredCompanies.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCompanies.length,
                  itemBuilder: (context, index) {
                    final company = _filteredCompanies[index];
                    return _buildCompanyItem(company, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping,
            color: theme.colorScheme.onSurfaceVariant,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无物流公司',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加物流公司',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyItem(LogisticsCompany company, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: company.isActive ? theme.colorScheme.primary.withOpacity(0.3) : theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showCompanyDetail(company),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            company.code,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          if (company.phone != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  company.phone!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: company.isActive 
                            ? theme.colorScheme.primary.withOpacity(0.15)
                            : theme.colorScheme.outlineVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        company.isActive ? '启用中' : '已停用',
                        style: TextStyle(
                          color: company.isActive 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTrackingDialog(company),
                        icon: const Icon(Icons.track_changes),
                        label: const Text('物流追踪'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleCompanyStatus(company),
                        icon: Icon(company.isActive ? Icons.pause : Icons.play_arrow),
                        label: Text(company.isActive ? '停用' : '启用'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: company.isActive 
                              ? theme.colorScheme.error 
                              : theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '物流追踪',
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入运单号查询物流状态',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          _buildQuickTrackingCard(theme),
          const SizedBox(height: 24),
          _buildRecentTrackingCard(theme),
        ],
      ),
    );
  }

  Widget _buildQuickTrackingCard(ThemeData theme) {
    final trackingController = TextEditingController();
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  '快速查询',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: trackingController,
              decoration: InputDecoration(
                hintText: '请输入运单号',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.confirmation_number, color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (trackingController.text.isNotEmpty) {
                    final company = _logisticsCompanies.firstWhere(
                      (c) => c.isActive,
                      orElse: () => _logisticsCompanies.first,
                    );
                    _showTrackingResult(company, trackingController.text);
                  }
                },
                icon: const Icon(Icons.search),
                label: const Text('查询物流'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrackingCard(ThemeData theme) {
    final recentTrackings = [
      {'number': 'SF1234567890', 'status': '已签收', 'time': '2天前'},
      {'number': 'YTO0987654321', 'status': '运输中', 'time': '1天前'},
      {'number': 'ZTO1122334455', 'status': '已揽收', 'time': '3小时前'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  '最近查询',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentTrackings.map((tracking) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    final company = _logisticsCompanies.firstWhere(
                      (c) => c.isActive,
                      orElse: () => _logisticsCompanies.first,
                    );
                    _showTrackingResult(company, tracking['number'] as String);
                  },
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.confirmation_number,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    tracking['number'] as String,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    tracking['time'] as String,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (tracking['status'] == '已签收')
                          ? Colors.green.withOpacity(0.15)
                          : (tracking['status'] == '运输中')
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tracking['status'] as String,
                      style: TextStyle(
                        color: (tracking['status'] == '已签收')
                            ? Colors.green
                            : (tracking['status'] == '运输中')
                                ? theme.colorScheme.primary
                                : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
