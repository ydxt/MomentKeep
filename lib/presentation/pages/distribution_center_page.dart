import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class DistributionCenterPage extends ConsumerStatefulWidget {
  const DistributionCenterPage({super.key});

  @override
  ConsumerState<DistributionCenterPage> createState() => _DistributionCenterPageState();
}

class _DistributionCenterPageState extends ConsumerState<DistributionCenterPage> {
  final DatabaseService _databaseService = DatabaseService();
  final ProductDatabaseService _productDatabaseService = ProductDatabaseService();
  
  Map<String, dynamic> _userInfo = {};
  List<Map<String, dynamic>> _distributionProducts = [];
  List<Map<String, dynamic>> _myTeam = [];
  List<Map<String, dynamic>> _commissionRecords = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      
      // 加载用户信息
      _userInfo = {
        'userId': userId,
        'userName': '用户',
        'totalCommission': 0.0,
        'withdrawableCommission': 0.0,
        'totalOrders': 0,
        'teamSize': 0,
      };

      // 加载可分销商品
      final products = await _productDatabaseService.getActiveProducts();
      _distributionProducts = products.take(10).map((p) {
        final product = StarProduct.fromMap(p);
        return {
          'product': product,
          'commissionRate': 0.1 + (product.totalSales % 5) * 0.02, // 模拟佣金率 10%-20%
        };
      }).toList();

      // 加载我的团队（模拟数据）
      _myTeam = [
        {
          'userId': 'user_001',
          'userName': '张三',
          'joinDate': DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
          'totalOrders': 5,
          'totalAmount': 500.0,
        },
        {
          'userId': 'user_002',
          'userName': '李四',
          'joinDate': DateTime.now().subtract(const Duration(days: 15)).millisecondsSinceEpoch,
          'totalOrders': 3,
          'totalAmount': 300.0,
        },
      ];

      // 加载佣金记录（模拟数据）
      _commissionRecords = [
        {
          'type': 'order',
          'description': '订单佣金 - 商品A',
          'amount': 25.5,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          'status': '已到账',
        },
        {
          'type': 'team',
          'description': '团队奖励 - 张三下单',
          'amount': 15.0,
          'timestamp': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          'status': '已到账',
        },
        {
          'type': 'withdrawal',
          'description': '提现申请',
          'amount': -100.0,
          'timestamp': DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
          'status': '处理中',
        },
      ];

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载分销数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showShareDialog(Map<String, dynamic> productData) {
    final theme = ref.read(currentThemeProvider);
    final product = productData['product'] as StarProduct;
    final commissionRate = productData['commissionRate'] as double;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.background,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '分享赚佣金',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 商品信息
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.image,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(Icons.image, color: theme.colorScheme.onSurfaceVariant),
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
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${product.price}',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 佣金信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '佣金比例',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '${(commissionRate * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '预计佣金',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '¥${(product.price * commissionRate).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 分享按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('链接已复制，快去分享给好友吧！')),
                  );
                },
                icon: Icon(Icons.share),
                label: Text('复制链接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('海报生成功能开发中')),
                  );
                },
                icon: Icon(Icons.image),
                label: Text('生成海报'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
    final theme = ref.watch(currentThemeProvider);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        foregroundColor: theme.colorScheme.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '分销中心',
          style: TextStyle(color: theme.colorScheme.onBackground),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : Column(
              children: [
                // 收益概览卡片
                _buildIncomeCard(theme),
                
                // Tab导航
                _buildTabBar(theme),
                
                // Tab内容
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildProductsTab(theme),
                      _buildTeamTab(theme),
                      _buildCommissionTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIncomeCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '累计佣金',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${_userInfo['totalCommission'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showWithdrawDialog(theme),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text('提现'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIncomeStat('可提现', '¥${_userInfo['withdrawableCommission'].toStringAsFixed(2)}', theme),
              _buildIncomeStat('团队人数', '${_userInfo['teamSize']}人', theme),
              _buildIncomeStat('推广订单', '${_userInfo['totalOrders']}单', theme),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(ThemeData theme) {
    final withdrawable = _userInfo['withdrawableCommission'] as double? ?? 0.0;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('佣金提现', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '可提现金额: ¥${withdrawable.toStringAsFixed(2)}',
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '提现金额',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  prefixText: '¥ ',
                  prefixStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                '提现将在1-3个工作日内到账',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('请输入有效的提现金额'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (amount > withdrawable) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('提现金额不能超过可提现余额'), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final db = await _productDatabaseService.database;
                  await db.insert('commission_withdrawals', {
                    'user_id': userId,
                    'amount': amount,
                    'status': 'pending',
                    'created_at': now,
                    'updated_at': now,
                  });
                  setState(() {
                    _userInfo['withdrawableCommission'] = withdrawable - amount;
                    _userInfo['totalCommission'] = (_userInfo['totalCommission'] as double? ?? 0.0) - amount;
                  });
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('提现申请已提交，金额 ¥${amount.toStringAsFixed(2)}'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('提现申请失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text('确认提现'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncomeStat(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _buildTabItem('推广商品', 0, theme),
          _buildTabItem('我的团队', 1, theme),
          _buildTabItem('佣金明细', 2, theme),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, ThemeData theme) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: isSelected
                  ? BorderSide(color: theme.colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _distributionProducts.length,
      itemBuilder: (context, index) {
        final productData = _distributionProducts[index];
        final product = productData['product'] as StarProduct;
        final commissionRate = productData['commissionRate'] as double;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.image,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: theme.colorScheme.surfaceVariant,
                    child: Icon(Icons.image, color: theme.colorScheme.onSurfaceVariant),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¥${product.price}',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '佣金 ${(commissionRate * 100).toStringAsFixed(1)}% · 赚¥${(product.price * commissionRate).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _showShareDialog(productData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text('分享'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamTab(ThemeData theme) {
    if (_myTeam.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无团队成员',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('邀请链接已复制')),
                );
              },
              icon: Icon(Icons.person_add),
              label: Text('邀请好友'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myTeam.length,
      itemBuilder: (context, index) {
        final member = _myTeam[index];
        final joinDate = DateTime.fromMillisecondsSinceEpoch(member['joinDate'] as int);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Text(
                  member['userName'][0],
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['userName'],
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '加入时间: ${joinDate.year}-${joinDate.month.toString().padLeft(2, '0')}-${joinDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${member['totalOrders']}单',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${member['totalAmount'].toStringAsFixed(0)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommissionTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _commissionRecords.length,
      itemBuilder: (context, index) {
        final record = _commissionRecords[index];
        final timestamp = record['timestamp'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final isWithdrawal = record['type'] == 'withdrawal';
        final amount = record['amount'] as double;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isWithdrawal
                      ? theme.colorScheme.error.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWithdrawal ? Icons.trending_down : Icons.trending_up,
                  color: isWithdrawal
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['description'] as String,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isWithdrawal ? '-' : '+'}¥${amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isWithdrawal
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      record['status'] as String,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
