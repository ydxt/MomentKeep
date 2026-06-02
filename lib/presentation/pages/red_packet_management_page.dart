import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';

class RedPacketManagementPage extends ConsumerStatefulWidget {
  const RedPacketManagementPage({super.key});

  @override
  ConsumerState<RedPacketManagementPage> createState() => _RedPacketManagementPageState();
}

class _RedPacketManagementPageState extends ConsumerState<RedPacketManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RedPacket> _redPackets = [];
  List<RedPacketClaim> _claims = [];
  bool _isLoading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final db = ProductDatabaseService();
      final packets = await db.getAllRedPackets();
      final now = DateTime.now().millisecondsSinceEpoch;
      bool needRefresh = false;
      for (final rp in packets) {
        if (rp.isActive && rp.endTime != null && rp.endTime!.millisecondsSinceEpoch < now) {
          final updated = RedPacket(
            id: rp.id,
            name: rp.name,
            type: rp.type,
            rewardType: rp.rewardType,
            totalAmount: rp.totalAmount,
            totalCount: rp.totalCount,
            receivedCount: rp.receivedCount,
            minAmount: rp.minAmount,
            maxAmount: rp.maxAmount,
            startTime: rp.startTime,
            endTime: rp.endTime,
            description: rp.description,
            isActive: false,
            createdAt: rp.createdAt,
            updatedAt: DateTime.now(),
          );
          await db.updateRedPacket(rp.id!, updated);
          needRefresh = true;
        }
      }
      final finalPackets = needRefresh ? await db.getAllRedPackets() : packets;
      final allClaims = await db.getAllRedPacketClaims();
      if (mounted) {
        setState(() {
          _redPackets = finalPackets;
          _claims = allClaims;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<RedPacket> get _filteredRedPackets {
    switch (_statusFilter) {
      case 'active':
        return _redPackets.where((rp) => rp.isActive).toList();
      case 'ended':
        return _redPackets.where((rp) => !rp.isActive).toList();
      default:
        return _redPackets;
    }
  }

  String _getStatusText(RedPacket rp) {
    if (!rp.isActive) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (rp.endTime != null && rp.endTime!.millisecondsSinceEpoch < now) {
        return '已过期';
      }
      return '已结束';
    }
    return '进行中';
  }

  Color _getStatusColor(RedPacket rp, ThemeData theme) {
    if (!rp.isActive) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (rp.endTime != null && rp.endTime!.millisecondsSinceEpoch < now) {
        return Colors.orange;
      }
      return theme.colorScheme.onSurfaceVariant;
    }
    return Colors.green;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCreateRedPacketDialog() {
    final theme = ref.watch(currentThemeProvider);
    String name = '';
    String type = 'fixed';
    String rewardType = 'cash';
    int totalAmount = 0;
    int totalCount = 100;
    int? minAmount;
    int? maxAmount;
    DateTime endTime = DateTime.now().add(const Duration(days: 30));
    bool isPermanent = false;
    String description = '';

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
                    items: const [
                      DropdownMenuItem(value: 'fixed', child: Text('固定金额红包')),
                      DropdownMenuItem(value: 'random', child: Text('随机金额红包')),
                    ],
                    onChanged: (value) => setDialogState(() => type = value!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: rewardType,
                    decoration: InputDecoration(
                      labelText: '奖励类型',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('现金')),
                      DropdownMenuItem(value: 'points', child: Text('积分')),
                    ],
                    onChanged: (value) => setDialogState(() => rewardType = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: type == 'fixed'
                          ? (rewardType == 'points' ? '单个红包积分' : '单个红包金额(分)')
                          : (rewardType == 'points' ? '总积分' : '总金额(分)'),
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => totalAmount = int.tryParse(value) ?? 0,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => totalCount = int.tryParse(value) ?? 100,
                  ),
                  if (type == 'random') ...[
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: rewardType == 'points' ? '最小积分' : '最小金额(分)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => minAmount = int.tryParse(value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: rewardType == 'points' ? '最大积分' : '最大金额(分)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => maxAmount = int.tryParse(value),
                    ),
                  ],
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
                    onChanged: (value) => description = value,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: isPermanent,
                    onChanged: (value) => setDialogState(() => isPermanent = value),
                    title: Text('永久有效', style: TextStyle(color: theme.colorScheme.onSurface)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: isPermanent ? null : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => endTime = picked);
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
                      child: Text(
                        isPermanent ? '永久有效' : endTime.toString().substring(0, 10),
                        style: TextStyle(
                          color: isPermanent ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                        ),
                      ),
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
              onPressed: () async {
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('请输入红包名称', style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final now = DateTime.now();
                final redPacket = RedPacket(
                  name: name,
                  type: type,
                  rewardType: rewardType,
                  totalAmount: totalAmount,
                  totalCount: totalCount,
                  receivedCount: 0,
                  minAmount: minAmount,
                  maxAmount: maxAmount,
                  startTime: now,
                  endTime: isPermanent ? null : endTime,
                  description: description.isNotEmpty ? description : null,
                  isActive: true,
                  createdAt: now,
                  updatedAt: now,
                );
                await ProductDatabaseService().insertRedPacket(redPacket);
                if (mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('红包创建成功');
                  _loadData();
                }
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

  void _showDistributeDialog(RedPacket redPacket) {
    final theme = ref.watch(currentThemeProvider);
    String distributeType = 'all';
    List<String> selectedUserIds = [];
    int count = 1;
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('发放红包 - ${redPacket.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
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
                    Text('通过用户ID发放', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '用户ID列表',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        hintText: '如: user1, user2, user3',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      onChanged: (value) {
                        selectedUserIds = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('通过用户邮箱发放', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: '用户邮箱列表',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        hintText: '如: user1@example.com, user2@example.com',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              onPressed: () async {
                final db = ProductDatabaseService();
                final personalDbService = DatabaseService();
                final userDbService = UserDatabaseService();
                final now = DateTime.now();
                final amountPerPerson = redPacket.type == 'fixed'
                    ? (redPacket.totalAmount ~/ redPacket.totalCount)
                    : ((redPacket.minAmount ?? 0) + (redPacket.maxAmount ?? redPacket.totalAmount)) ~/ 2;

                if (distributeType == 'all') {
                  for (int i = 0; i < count; i++) {
                    final claim = RedPacketClaim(
                      redPacketId: redPacket.id!,
                      userId: 'all',
                      amount: amountPerPerson,
                      claimedAt: now,
                    );
                    await db.insertRedPacketClaim(claim);
                    await db.incrementRedPacketReceivedCount(redPacket.id!);
                    await personalDbService.insertRedPacketClaim({
                      'red_packet_id': redPacket.id!,
                      'user_id': 'all',
                      'amount': amountPerPerson,
                      'claimed_at': now.millisecondsSinceEpoch,
                    });
                  }
                } else {
                  final List<String> finalUserIds = List.from(selectedUserIds);

                  final emailText = emailController.text.trim();
                  if (emailText.isNotEmpty) {
                    final emails = emailText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    for (final email in emails) {
                      final user = await userDbService.getUserByEmail(email);
                      if (user != null) {
                        final userId = user['user_id'] as String?;
                        if (userId != null && userId.isNotEmpty && !finalUserIds.contains(userId)) {
                          finalUserIds.add(userId);
                        }
                      }
                    }
                  }

                  for (final userId in finalUserIds) {
                    for (int i = 0; i < count; i++) {
                      final claim = RedPacketClaim(
                        redPacketId: redPacket.id!,
                        userId: userId,
                        amount: amountPerPerson,
                        claimedAt: now,
                      );
                      await db.insertRedPacketClaim(claim);
                      await db.incrementRedPacketReceivedCount(redPacket.id!);
                      await personalDbService.insertRedPacketClaim({
                        'red_packet_id': redPacket.id!,
                        'user_id': userId,
                        'amount': amountPerPerson,
                        'claimed_at': now.millisecondsSinceEpoch,
                      });
                    }
                  }
                }
                if (mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('红包发放成功');
                  _loadData();
                }
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

  void _showEndActivityDialog(RedPacket redPacket) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('结束活动', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: Text('确定要结束红包「${redPacket.name}」的活动吗？结束后将无法继续发放。', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = RedPacket(
                id: redPacket.id,
                name: redPacket.name,
                type: redPacket.type,
                rewardType: redPacket.rewardType,
                totalAmount: redPacket.totalAmount,
                totalCount: redPacket.totalCount,
                receivedCount: redPacket.receivedCount,
                minAmount: redPacket.minAmount,
                maxAmount: redPacket.maxAmount,
                startTime: redPacket.startTime,
                endTime: redPacket.endTime,
                description: redPacket.description,
                isActive: false,
                createdAt: redPacket.createdAt,
                updatedAt: DateTime.now(),
              );
              await ProductDatabaseService().updateRedPacket(redPacket.id!, updated);
              if (mounted) {
                Navigator.pop(context);
                _showSuccessSnackBar('活动已结束');
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定结束'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(RedPacket redPacket) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('删除红包', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: Text('确定要删除红包「${redPacket.name}」吗？删除后不可恢复！', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ProductDatabaseService().deleteRedPacket(redPacket.id!);
              if (mounted) {
                Navigator.pop(context);
                _showSuccessSnackBar('红包已删除');
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog(RedPacket redPacket) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('红包统计 - ${redPacket.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('总发放', '${redPacket.totalCount}', theme.colorScheme.error, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('已领取', '${redPacket.receivedCount}', theme.colorScheme.secondary, theme),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('总金额',
                      redPacket.rewardType == 'points'
                          ? '${redPacket.totalAmount}积分'
                          : '${(redPacket.totalAmount / 100).toStringAsFixed(2)}元',
                      theme.colorScheme.tertiary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '领取率',
                      redPacket.totalCount > 0
                          ? '${((redPacket.receivedCount / redPacket.totalCount) * 100).toStringAsFixed(1)}%'
                          : '0%',
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

  Widget _buildFilterChips(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _statusFilter == 'all',
            onSelected: (_) => setState(() => _statusFilter = 'all'),
            selectedColor: theme.colorScheme.error.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('进行中'),
            selected: _statusFilter == 'active',
            onSelected: (_) => setState(() => _statusFilter = 'active'),
            selectedColor: Colors.green.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('已结束'),
            selected: _statusFilter == 'ended',
            onSelected: (_) => setState(() => _statusFilter = 'ended'),
            selectedColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildRedPacketList(ThemeData theme) {
    final filtered = _filteredRedPackets;
    return Column(
      children: [
        _buildFilterChips(theme),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '暂无红包数据',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: theme.colorScheme.error,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final rp = filtered[index];
                      return _buildRedPacketCard(rp, theme);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRedPacketCard(RedPacket rp, ThemeData theme) {
    final statusText = _getStatusText(rp);
    final statusColor = _getStatusColor(rp, theme);
    final amountPerUnit = rp.type == 'fixed' && rp.totalCount > 0
        ? rp.totalAmount ~/ rp.totalCount
        : rp.totalAmount;

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
                      rp.name,
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
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
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
                    rp.rewardType == 'points' ? '积分' : '¥',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    rp.rewardType == 'points' ? amountPerUnit.toString() : (amountPerUnit / 100).toStringAsFixed(2),
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          rp.type == 'fixed' ? '固定金额红包' : '随机金额红包',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: rp.rewardType == 'points'
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rp.rewardType == 'points' ? '积分' : '现金',
                            style: TextStyle(
                              color: rp.rewardType == 'points' ? Colors.amber.shade700 : Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rp.description != null && rp.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '祝福语: ${rp.description}',
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
                    '已领取: ${rp.receivedCount}/${rp.totalCount}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '有效期至: ${rp.endTime != null ? rp.endTime!.toString().substring(0, 10) : "无期限"}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (rp.isActive) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDistributeDialog(rp),
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('发放'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEndActivityDialog(rp),
                        icon: const Icon(Icons.stop_circle, size: 18),
                        label: const Text('结束活动'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!rp.isActive)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteDialog(rp),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  if (!rp.isActive) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatisticsDialog(rp),
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
  }

  Widget _buildDistributeRecords(ThemeData theme) {
    if (_claims.isEmpty) {
      return Center(
        child: Text(
          '暂无发放记录',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: theme.colorScheme.error,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length,
        itemBuilder: (context, index) {
          final claim = _claims[index];
          final rp = _redPackets.where((r) => r.id == claim.redPacketId).firstOrNull;
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
                      rp?.name ?? '红包#${claim.redPacketId}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          claim.userId,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.account_balance_wallet, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          rp != null && rp.rewardType == 'points'
                              ? '${claim.amount}积分'
                              : '${(claim.amount / 100).toStringAsFixed(2)}元',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          claim.claimedAt.toString().substring(0, 16),
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
      ),
    );
  }
}
