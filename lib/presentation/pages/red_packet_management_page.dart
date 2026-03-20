import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class RedPacketManagementPage extends ConsumerStatefulWidget {
  const RedPacketManagementPage({super.key});

  @override
  ConsumerState<RedPacketManagementPage> createState() => _RedPacketManagementPageState();
}

class _RedPacketManagementPageState extends ConsumerState<RedPacketManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _redPackets = [];
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
    _redPackets = [
      {
        'id': '1',
        'name': '新人红包',
        'type': '现金红包',
        'amount': 10,
        'validity': '2025-12-31',
        'totalCount': 2000,
        'usedCount': 1234,
        'receivedCount': 1567,
        'status': '进行中',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': '2',
        'name': '生日红包',
        'type': '积分红包',
        'amount': 50,
        'validity': '2025-12-31',
        'totalCount': 500,
        'usedCount': 234,
        'receivedCount': 345,
        'status': '进行中',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': '3',
        'name': '节日红包',
        'type': '现金红包',
        'amount': 20,
        'validity': '2025-02-15',
        'totalCount': 1000,
        'usedCount': 890,
        'receivedCount': 950,
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

  void _showCreateRedPacketDialog() {
    final theme = ref.watch(currentThemeProvider);
    String name = '';
    String type = '现金红包';
    double amount = 0;
    int totalCount = 100;
    DateTime validity = DateTime.now().add(const Duration(days: 30));
    String greeting = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('创建红包', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: '红包名称',
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
                      labelText: '红包类型',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    items: ['现金红包', '积分红包'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (value) => setDialogState(() => type = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '红包金额',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      prefixText: type == '积分红包' ? '✨' : '¥',
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
                  TextField(
                    decoration: InputDecoration(
                      labelText: '祝福语（可选）',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    onChanged: (value) => greeting = value,
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
                  _redPackets.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': name,
                    'type': type,
                    'amount': amount,
                    'greeting': greeting,
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
                    content: Text('红包创建成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistributeDialog(Map<String, dynamic> redPacket) {
    final theme = ref.watch(currentThemeProvider);
    String distributeType = 'all';
    List<String> selectedUserIds = [];
    int count = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('发放红包 - ${redPacket['name']}', style: TextStyle(color: theme.colorScheme.onBackground)),
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
                    content: Text('红包发放成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('发放'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatisticsDialog(Map<String, dynamic> redPacket) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('红包统计 - ${redPacket['name']}', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('总发放', '${redPacket['totalCount']}', theme.colorScheme.error, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('已领取', '${redPacket['receivedCount']}', theme.colorScheme.secondary, theme),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('已使用', '${redPacket['usedCount']}', theme.colorScheme.tertiary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '使用率',
                      '${(((redPacket['usedCount'] as num) / (redPacket['totalCount'] as num)) * 100).toStringAsFixed(1)}%',
                      theme.colorScheme.primary,
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
        title: const Text('红包管理'),
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
              labelColor: theme.colorScheme.error,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.error,
              tabs: const [
                Tab(text: '红包列表'),
                Tab(text: '发放记录'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.error))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRedPacketList(theme),
                _buildDistributeRecords(theme),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRedPacketDialog,
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRedPacketList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _redPackets.length,
      itemBuilder: (context, index) {
        final redPacket = _redPackets[index];
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
                          redPacket['name'],
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
                          color: redPacket['status'] == '进行中'
                              ? theme.colorScheme.error.withOpacity(0.2)
                              : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          redPacket['status'],
                          style: TextStyle(
                            color: redPacket['status'] == '进行中' ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        redPacket['type'] == '积分红包' ? '✨' : '¥',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${redPacket['amount'] as num}',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          redPacket['type'],
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (redPacket['greeting'] != null && (redPacket['greeting'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '祝福语: ${redPacket['greeting'] as String}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '已使用: ${redPacket['usedCount'] as int}/${redPacket['totalCount'] as int}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '有效期至: ${redPacket['validity']}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (redPacket['status'] == '进行中')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDistributeDialog(redPacket),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('发放'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                          ),
                        ),
                      if (redPacket['status'] == '进行中') const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showStatisticsDialog(redPacket),
                          icon: const Icon(Icons.analytics, size: 18),
                          label: const Text('统计'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
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
        'redPacketName': '新人红包',
        'distributeType': '全体用户',
        'count': 1000,
        'time': DateTime.now().millisecondsSinceEpoch - 3600000,
        'operator': '管理员',
      },
      {
        'id': '2',
        'redPacketName': '生日红包',
        'distributeType': '指定用户',
        'count': 30,
        'time': DateTime.now().millisecondsSinceEpoch - 86400000,
        'operator': '管理员',
      },
      {
        'id': '3',
        'redPacketName': '节日红包',
        'distributeType': '按等级(VIP2+)',
        'count': 500,
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
                    record['redPacketName'] as String,
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
                        '${record['count'] as int}个',
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
