import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 管理员综合后台页面
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final ProductDatabaseService _productDbService = ProductDatabaseService();
  
  late TabController _tabController;
  
  // 平台统计数据
  Map<String, dynamic> _platformStats = {};
  bool _isLoadingStats = true;
  
  // 商品审核数据
  List<Map<String, dynamic>> _pendingProducts = [];
  bool _isLoadingProducts = true;
  
  // 系统公告数据
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  
  // 趋势数据
  List<Map<String, dynamic>> _userTrendData = [];
  List<Map<String, dynamic>> _orderTrendData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载所有数据
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadPlatformStats(),
      _loadPendingProducts(),
      _loadAnnouncements(),
      _loadTrendData(),
    ]);
  }

  /// 加载平台统计数据
  Future<void> _loadPlatformStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final db = await _databaseService.database;
      final productDb = await _productDbService.database;

      // 获取用户总数
      final userCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM users');
      final totalUsers = userCountResult.isNotEmpty ? userCountResult[0]['count'] as int : 0;

      // 获取商品总数
      final productCountResult = await productDb.rawQuery('SELECT COUNT(*) as count FROM star_products');
      final totalProducts = productCountResult.isNotEmpty ? productCountResult[0]['count'] as int : 0;

      // 获取订单总数
      final orderCountResult = await productDb.rawQuery('SELECT COUNT(*) as count FROM star_orders');
      final totalOrders = orderCountResult.isNotEmpty ? orderCountResult[0]['count'] as int : 0;

      // 获取交易总额（现金部分）
      final revenueResult = await productDb.rawQuery('SELECT SUM(actual_paid_amount) as total FROM star_orders WHERE status = "completed"');
      final totalRevenue = revenueResult.isNotEmpty ? (revenueResult[0]['total'] ?? 0) as num : 0;

      // 获取待审核商品数
      final pendingResult = await productDb.rawQuery('SELECT COUNT(*) as count FROM star_products WHERE status = "pending"');
      final pendingProducts = pendingResult.isNotEmpty ? pendingResult[0]['count'] as int : 0;

      setState(() {
        _platformStats = {
          'totalUsers': totalUsers,
          'totalProducts': totalProducts,
          'totalOrders': totalOrders,
          'totalRevenue': totalRevenue,
          'pendingProducts': pendingProducts,
        };
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading platform stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  /// 加载待审核商品
  Future<void> _loadPendingProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final productDb = await _productDbService.database;
      final products = await productDb.rawQuery('''
        SELECT p.*, m.username as merchant_name 
        FROM star_products p 
        LEFT JOIN merchants m ON p.merchant_id = m.id 
        WHERE p.status = 'pending' 
        ORDER BY p.created_at DESC
      ''');

      setState(() {
        _pendingProducts = products.cast<Map<String, dynamic>>();
        _isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading pending products: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  /// 加载系统公告
  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoadingAnnouncements = true;
    });

    try {
      final db = await _databaseService.database;
      
      // 检查公告表是否存在，不存在则创建
      await db.execute('''
        CREATE TABLE IF NOT EXISTS system_announcements (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');

      final announcements = await db.rawQuery('''
        SELECT * FROM system_announcements 
        WHERE is_active = 1 
        ORDER BY created_at DESC
      ''');

      setState(() {
        _announcements = announcements.cast<Map<String, dynamic>>();
        _isLoadingAnnouncements = false;
      });
    } catch (e) {
      print('Error loading announcements: $e');
      setState(() {
        _isLoadingAnnouncements = false;
      });
    }
  }

  /// 加载趋势数据
  Future<void> _loadTrendData() async {
    try {
      final db = await _databaseService.database;
      final productDb = await _productDbService.database;

      final now = DateTime.now();
      final days = 30;
      final startDate = now.subtract(Duration(days: days - 1));

      final userTrend = <Map<String, dynamic>>[];
      final orderTrend = <Map<String, dynamic>>[];

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayStart = date.millisecondsSinceEpoch;
        final dayEnd = date.add(const Duration(days: 1)).millisecondsSinceEpoch;

        // 每日用户注册数
        final userCountResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM users WHERE created_at >= ? AND created_at < ?',
          [dayStart, dayEnd]
        );
        final userCount = userCountResult.isNotEmpty ? userCountResult[0]['count'] as int : 0;

        // 每日订单数
        final orderCountResult = await productDb.rawQuery(
          'SELECT COUNT(*) as count FROM star_orders WHERE created_at >= ? AND created_at < ?',
          [dayStart, dayEnd]
        );
        final orderCount = orderCountResult.isNotEmpty ? orderCountResult[0]['count'] as int : 0;

        userTrend.add({'date': dateStr, 'count': userCount});
        orderTrend.add({'date': dateStr, 'count': orderCount});
      }

      setState(() {
        _userTrendData = userTrend;
        _orderTrendData = orderTrend;
      });
    } catch (e) {
      print('Error loading trend data: $e');
    }
  }

  /// 审核商品
  Future<void> _reviewProduct(String productId, bool approved) async {
    try {
      final productDb = await _productDbService.database;
      await productDb.update(
        'star_products',
        {
          'status': approved ? 'approved' : 'rejected',
          'reviewed_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? '商品审核通过' : '商品审核拒绝')),
      );

      // 重新加载数据
      await _loadPendingProducts();
      await _loadPlatformStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('审核失败: $e')),
      );
    }
  }

  /// 发布公告
  Future<void> _publishAnnouncement() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发布系统公告'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: '内容'),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('发布'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
      try {
        final db = await _databaseService.database;
        final announcementId = DateTime.now().millisecondsSinceEpoch.toString();
        
        await db.insert('system_announcements', {
          'id': announcementId,
          'title': titleController.text,
          'content': contentController.text,
          'created_by': 'admin',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'is_active': 1,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('公告发布成功')),
        );

        await _loadAnnouncements();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('公告发布失败: $e')),
        );
      }
    }
  }

  /// 删除公告
  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      final db = await _databaseService.database;
      await db.update(
        'system_announcements',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [announcementId],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公告已删除')),
      );

      await _loadAnnouncements();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除公告失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理员后台'),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '数据统计'),
            Tab(icon: Icon(Icons.verified_user), text: '商品审核'),
            Tab(icon: Icon(Icons.announcement), text: '系统公告'),
            Tab(icon: Icon(Icons.people), text: '用户管理'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(theme),
          _buildProductReviewTab(theme),
          _buildAnnouncementsTab(theme),
          _buildUsersTab(theme),
        ],
      ),
    );
  }

  /// 数据统计标签页
  Widget _buildDashboardTab(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        // 统计卡片
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        theme,
                        '总用户数',
                        '${_platformStats['totalUsers'] ?? 0}',
                        Icons.people,
                        theme.colorScheme.primary,
                      ),
                      _buildStatCard(
                        theme,
                        '总商品数',
                        '${_platformStats['totalProducts'] ?? 0}',
                        Icons.inventory,
                        theme.colorScheme.secondary,
                      ),
                      _buildStatCard(
                        theme,
                        '总订单数',
                        '${_platformStats['totalOrders'] ?? 0}',
                        Icons.shopping_cart,
                        theme.colorScheme.tertiary,
                      ),
                      _buildStatCard(
                        theme,
                        '交易总额',
                        '¥${(_platformStats['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                        Icons.account_balance_wallet,
                        const Color(0xFF2A9D8F),
                      ),
                    ],
                  ),
          ),
        ),

        // 用户增长趋势图
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildUserTrendChart(theme),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // 订单趋势图
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildOrderTrendChart(theme),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建用户趋势图
  Widget _buildUserTrendChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '用户增长趋势',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_userTrendData.isEmpty)
            const SizedBox(height: 200, child: Center(child: Text('暂无数据')))
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _userTrendData.length && index % 5 == 0) {
                            final date = DateTime.parse(_userTrendData[index]['date']);
                            return Text(
                              '${date.month}/${date.day}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _userTrendData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['count'].toDouble())).toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.3),
                            theme.colorScheme.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
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

  /// 构建订单趋势图
  Widget _buildOrderTrendChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                '订单趋势',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_orderTrendData.isEmpty)
            const SizedBox(height: 200, child: Center(child: Text('暂无数据')))
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _orderTrendData.length && index % 5 == 0) {
                            final date = DateTime.parse(_orderTrendData[index]['date']);
                            return Text(
                              '${date.month}/${date.day}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _orderTrendData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value['count'].toDouble(),
                          color: theme.colorScheme.secondary,
                          width: 8,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 商品审核标签页
  Widget _buildProductReviewTab(ThemeData theme) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '暂无待审核商品',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingProducts.length,
      itemBuilder: (context, index) {
        final product = _pendingProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2, size: 32),
            ),
            title: Text(product['name'] ?? '未知商品'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('商家: ${product['merchant_name'] ?? '未知'}'),
                Text('价格: ¥${product['price'] ?? 0}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Color(0xFF2A9D8F)),
                  onPressed: () => _reviewProduct(product['id'], true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFE76F51)),
                  onPressed: () => _reviewProduct(product['id'], false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 系统公告标签页
  Widget _buildAnnouncementsTab(ThemeData theme) {
    return Column(
      children: [
        // 发布公告按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _publishAnnouncement,
            icon: const Icon(Icons.add),
            label: const Text('发布公告'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // 公告列表
        if (_isLoadingAnnouncements)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_announcements.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.announcement, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    '暂无系统公告',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                final createdAt = DateTime.fromMillisecondsSinceEpoch(announcement['created_at'] as int);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(announcement['title'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(announcement['content'] ?? ''),
                        const SizedBox(height: 8),
                        Text(
                          '发布于: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFE76F51)),
                      onPressed: () => _deleteAnnouncement(announcement['id']),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 用户管理标签页
  Widget _buildUsersTab(ThemeData theme) {
    return const Center(
      child: Text('用户管理功能与现有 admin_users_page.dart 相同'),
    );
  }
}
