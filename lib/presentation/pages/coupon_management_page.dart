import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class CouponManagementPage extends ConsumerStatefulWidget {
  const CouponManagementPage({super.key});

  @override
  ConsumerState<CouponManagementPage> createState() => _CouponManagementPageState();
}

class _CouponManagementPageState extends ConsumerState<CouponManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMockData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMockData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _coupons = [
      {
        'id': '1',
        'name': '满100减20优惠券',
        'type': '满减券',
        'amount': 20,
        'condition': 100,
        'validity': '2025-12-31',
        'totalCount': 1000,
        'usedCount': 345,
        'receivedCount': 567,
        'status': '进行中',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': '2',
        'name': '全场9折优惠券',
        'type': '折扣券',
        'discount': 0.9,
        'condition': 0,
        'validity': '2025-12-31',
        'totalCount': 500,
        'usedCount': 123,
        'receivedCount': 234,
        'status': '进行中',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': '3',
        'name': '新人专享券',
        'type': '满减券',
        'amount': 50,
        'condition': 200,
        'validity': '2025-06-30',
        'totalCount': 200,
        'usedCount': 89,
        'receivedCount': 150,
        'status': '已结束',
        'createdAt': DateTime.now().millisecondsSinceEpoch - 86400000 * 30,
      },
    ];

    _users = [
      {'id': '1', 'name': '张三', 'phone': '138****1234', 'level': 'VIP3'},
      {'id': '2', 'name': '李四', 'phone': '139****5678', 'level': 'VIP2'},
      {'id': '3', 'name': '王五', 'phone': '137****9012', 'level': 'VIP1'},
      {'id': '4', 'name': '赵六', 'phone': '136****3456', 'level': 'VIP4'},
      {'id': '5', 'name': '钱七', 'phone': '135****7890', 'level': 'VIP2'},
    ];

    setState(() {
      _isLoading = false;
    });
  }

  void _showCreateCouponDialog() {
    final theme = ref.watch(currentThemeProvider);
    String name = '';
    String type = '满减券';
    double amount = 0;
    double discount = 0.9;
    double condition = 0;
    int totalCount = 100;
    DateTime validity = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('创建优惠券', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: '优惠券名称',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: InputDecoration(
                      labelText: '优惠券类型',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    items: ['满减券', '折扣券'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (value) => setDialogState(() => type = value!),
                  ),
                  const SizedBox(height: 16),
                  if (type == '满减券')
                    TextField(
                      decoration: InputDecoration(
                        labelText: '优惠金额',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixText: '¥',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => amount = double.tryParse(value) ?? 0,
                    ),
                  if (type == '折扣券')
                    TextField(
                      decoration: InputDecoration(
                        labelText: '折扣',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        suffixText: '折',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => discount = (double.tryParse(value) ?? 9) / 10,
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '使用门槛（0为无门槛）',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      prefixText: '¥',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => condition = double.tryParse(value) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '发放数量',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => totalCount = int.tryParse(value) ?? 100,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: validity,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => validity = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '有效期至',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      child: Text(validity.toString().substring(0, 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _coupons.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': name,
                    'type': type,
                    'amount': amount,
                    'discount': discount,
                    'condition': condition,
                    'validity': validity.toString().substring(0, 10),
                    'totalCount': totalCount,
                    'usedCount': 0,
                    'receivedCount': 0,
                    'status': '进行中',
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('优惠券创建成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistributeDialog(Map<String, dynamic> coupon) {
    final theme = ref.watch(currentThemeProvider);
    String distributeType = 'all';
    List<String> selectedUserIds = [];
    int count = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('发放优惠券 - ${coupon['name']}', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发放方式', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('全体用户')),
                      ButtonSegment(value: 'selected', label: Text('指定用户')),
                      ButtonSegment(value: 'level', label: Text('按等级')),
                    ],
                    selected: {distributeType},
                    onSelectionChanged: (selection) => setDialogState(() => distributeType = selection.first),
                  ),
                  const SizedBox(height: 16),
                  if (distributeType == 'selected') ...[
                    Text('选择用户', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isSelected = selectedUserIds.contains(user['id']);
                          return CheckboxListTile(
                            title: Text(user['name']),
                            subtitle: Text('${user['phone']} · ${user['level']}'),
                            value: isSelected,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedUserIds.add(user['id']);
                                } else {
                                  selectedUserIds.remove(user['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  if (distributeType == 'level') ...[
                    Text('选择会员等级', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['VIP1', 'VIP2', 'VIP3', 'VIP4', 'VIP5']
                          .map((level) => FilterChip(
                                label: Text(level),
                                selected: selectedUserIds.contains(level),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedUserIds.add(level);
                                    } else {
                                      selectedUserIds.remove(level);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '每人发放数量',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => count = int.tryParse(value) ?? 1,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('优惠券发放成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('发放'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatisticsDialog(Map<String, dynamic> coupon) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('优惠券统计 - ${coupon['name']}', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('总发放', '${coupon['totalCount']}', theme.colorScheme.primary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('已领取', '${coupon['receivedCount']}', theme.colorScheme.secondary, theme),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('已使用', '${coupon['usedCount']}', theme.colorScheme.tertiary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '使用率',
                      '${(((coupon['usedCount'] as num) / (coupon['totalCount'] as num)) * 100).toStringAsFixed(1)}%',
                      theme.colorScheme.error,
                      theme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
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
        title: const Text('优惠券管理'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: '优惠券列表'),
                Tab(text: '发放记录'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCouponList(theme),
                _buildDistributeRecords(theme),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCouponDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCouponList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _coupons.length,
      itemBuilder: (context, index) {
        final coupon = _coupons[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          coupon['name'],
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: coupon['status'] == '进行中'
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          coupon['status'],
                          style: TextStyle(
                            color: coupon['status'] == '进行中' ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        coupon['type'] == '折扣券'
                            ? '${((coupon['discount'] as num) * 10).toStringAsFixed(0)}折'
                            : '¥${coupon['amount'] as num}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (coupon['condition'] as num) > 0 ? '满${coupon['condition'] as num}可用' : '无门槛使用',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '已使用: ${coupon['usedCount'] as int}/${coupon['totalCount'] as int}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '有效期至: ${coupon['validity']}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (coupon['status'] == '进行中')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDistributeDialog(coupon),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('发放'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      if (coupon['status'] == '进行中') const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showStatisticsDialog(coupon),
                          icon: const Icon(Icons.analytics, size: 18),
                          label: const Text('统计'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistributeRecords(ThemeData theme) {
    final records = [
      {
        'id': '1',
        'couponName': '满100减20优惠券',
        'distributeType': '全体用户',
        'count': 500,
        'time': DateTime.now().millisecondsSinceEpoch - 3600000,
        'operator': '管理员',
      },
      {
        'id': '2',
        'couponName': '全场9折优惠券',
        'distributeType': '指定用户',
        'count': 50,
        'time': DateTime.now().millisecondsSinceEpoch - 86400000,
        'operator': '管理员',
      },
      {
        'id': '3',
        'couponName': '新人专享券',
        'distributeType': '按等级(VIP1)',
        'count': 100,
        'time': DateTime.now().millisecondsSinceEpoch - 172800000,
        'operator': '管理员',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['couponName'] as String,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.category, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        record['distributeType'] as String,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.numbers, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${record['count'] as int}张',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        record['operator'] as String,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(record['time'] as int).toString().substring(0, 16),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
