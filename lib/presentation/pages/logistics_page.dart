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
  List<LogisticsTrack> _recentTracks = [];
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
      _recentTracks = await databaseService.getRecentLogisticsTracks(limit: 10);
    } catch (e) {
      debugPrint('加载物流数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载物流数据失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _showEditCompanyDialog(LogisticsCompany company) {
    final theme = ref.read(currentThemeProvider);
    final nameController = TextEditingController(text: company.name);
    final codeController = TextEditingController(text: company.code);
    final phoneController = TextEditingController(text: company.phone ?? '');
    final websiteController = TextEditingController(text: company.website ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('编辑物流公司', style: TextStyle(color: theme.colorScheme.onBackground)),
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
                    final updatedCompany = LogisticsCompany(
                      id: company.id,
                      name: nameController.text,
                      code: codeController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                      website: websiteController.text.isNotEmpty ? websiteController.text : null,
                      isActive: company.isActive,
                      sortOrder: company.sortOrder,
                      createdAt: company.createdAt,
                      updatedAt: DateTime.now(),
                    );
                    await databaseService.updateLogisticsCompany(company.id!, updatedCompany);
                    await _loadLogisticsData();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('物流公司更新成功'),
                          backgroundColor: theme.colorScheme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('更新失败: $e'),
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
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(LogisticsCompany company) {
    final theme = ref.read(currentThemeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('确认删除', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Text(
            '确定要删除物流公司「${company.name}」吗？此操作不可撤销。',
            style: TextStyle(color: theme.colorScheme.onSurface),
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
                try {
                  final databaseService = ProductDatabaseService();
                  await databaseService.deleteLogisticsCompany(company.id!);
                  await _loadLogisticsData();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('物流公司已删除'),
                        backgroundColor: theme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('删除失败: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('删除'),
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

  void _showTrackingResult(LogisticsCompany company, String trackingNumber) async {
    final theme = ref.read(currentThemeProvider);
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );

    try {
      final databaseService = ProductDatabaseService();
      List<LogisticsTrack> tracks = [];

      if (trackingNumber.isNotEmpty) {
        tracks = await databaseService.getLogisticsTracksByTrackingNumber(trackingNumber);
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (tracks.isEmpty) {
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    '未查询到该运单号的物流信息，请确认运单号是否已被录入系统',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
                ),
              ],
            );
          },
        );
        return;
      }

      final latestTrack = tracks.first;
      final statusInfo = _getStatusInfo(latestTrack.status);
      String? companyName = company.name;
      if (latestTrack.logisticsCompanyId != null) {
        final dbCompany = await databaseService.getLogisticsCompanyById(latestTrack.logisticsCompanyId!);
        if (dbCompany != null) companyName = dbCompany.name;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.background,
            title: Row(
              children: [
                Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '物流信息 - ${latestTrack.trackingNumber ?? trackingNumber}',
                    style: TextStyle(color: theme.colorScheme.onBackground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                      color: (statusInfo['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (statusInfo['color'] as Color).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusInfo['icon'] as IconData, color: statusInfo['color'] as Color, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusInfo['text'] as String,
                                style: TextStyle(
                                  color: statusInfo['color'] as Color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (companyName != null)
                                Text(
                                  '物流公司: $companyName',
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
                  ..._buildTrackingStepsFromData(tracks, theme),
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('查询物流信息失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'created':
        return {'text': '已发货', 'color': Colors.grey, 'icon': Icons.local_shipping};
      case 'picked':
        return {'text': '已揽收', 'color': Colors.blue, 'icon': Icons.local_mall};
      case 'transporting':
        return {'text': '运输中', 'color': Colors.orange, 'icon': Icons.local_shipping};
      case 'delivering':
        return {'text': '派送中', 'color': Colors.purple, 'icon': Icons.delivery_dining};
      case 'delivered':
        return {'text': '已签收', 'color': Colors.green, 'icon': Icons.check_circle};
      case 'exception':
        return {'text': '异常', 'color': Colors.red, 'icon': Icons.error};
      default:
        return {'text': '未知', 'color': Colors.grey, 'icon': Icons.help};
    }
  }

  List<Widget> _buildTrackingStepsFromData(List<LogisticsTrack> tracks, ThemeData theme) {
    return tracks.asMap().entries.map((entry) {
      final index = entry.key;
      final track = entry.value;
      final isFirst = index == 0;
      final isLast = index == tracks.length - 1;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isFirst ? theme.colorScheme.primary : theme.colorScheme.outline,
                  shape: BoxShape.circle,
                ),
                child: isFirst
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
                    track.description,
                    style: TextStyle(
                      color: isFirst ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (track.location != null && track.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      track.location!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(track.trackTime),
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
            Icons.local_shipping_outlined,
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCompanyDialog,
            icon: const Icon(Icons.add),
            label: const Text('添加物流公司'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                        label: const Text('追踪'),
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
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showEditCompanyDialog(company),
                      icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showDeleteConfirmDialog(company),
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  if (trackingController.text.isNotEmpty && _logisticsCompanies.isNotEmpty) {
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
    final groupedTracks = <String, LogisticsTrack>{};
    for (final track in _recentTracks) {
      final key = track.trackingNumber ?? track.orderId;
      if (!groupedTracks.containsKey(key)) {
        groupedTracks[key] = track;
      }
    }
    final recentItems = groupedTracks.values.toList();

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
                  '最近物流',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        '暂无物流记录',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentItems.map((track) {
                final statusInfo = _getStatusInfo(track.status);
                final displayNumber = track.trackingNumber ?? track.orderId;
                final timeDiff = DateTime.now().difference(track.trackTime);
                String timeText;
                if (timeDiff.inMinutes == 0) {
                  timeText = '刚刚';
                } else if (timeDiff.inHours == 0) {
                  timeText = '${timeDiff.inMinutes}分钟前';
                } else if (timeDiff.inDays == 0) {
                  timeText = '${timeDiff.inHours}小时前';
                } else {
                  timeText = '${timeDiff.inDays}天前';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      if (_logisticsCompanies.isNotEmpty) {
                        final company = _logisticsCompanies.firstWhere(
                          (c) => c.isActive,
                          orElse: () => _logisticsCompanies.first,
                        );
                        _showTrackingResult(company, displayNumber);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (statusInfo['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusInfo['icon'] as IconData,
                        color: statusInfo['color'] as Color,
                      ),
                    ),
                    title: Text(
                      displayNumber,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      timeText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (statusInfo['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusInfo['text'] as String,
                        style: TextStyle(
                          color: statusInfo['color'] as Color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
