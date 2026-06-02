import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';

class CouponManagementPage extends ConsumerStatefulWidget {
  const CouponManagementPage({super.key});

  @override
  ConsumerState<CouponManagementPage> createState() => _CouponManagementPageState();
}

class _CouponManagementPageState extends ConsumerState<CouponManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Coupon> _coupons = [];
  List<UserCoupon> _userCoupons = [];
  bool _isLoading = true;
  String _statusFilter = '全部';

  final _dbService = ProductDatabaseService();

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
    setState(() => _isLoading = true);

    try {
      final coupons = await _dbService.getAllCoupons();

      final now = DateTime.now().millisecondsSinceEpoch;
      bool needRefresh = false;
      for (final coupon in coupons) {
        if (coupon.isActive && coupon.endTime != null && coupon.endTime!.millisecondsSinceEpoch < now) {
          final updated = Coupon(
            id: coupon.id,
            name: coupon.name,
            code: coupon.code,
            type: coupon.type,
            rewardType: coupon.rewardType,
            value: coupon.value,
            minAmount: coupon.minAmount,
            maxDiscount: coupon.maxDiscount,
            totalCount: coupon.totalCount,
            usedCount: coupon.usedCount,
            startTime: coupon.startTime,
            endTime: coupon.endTime,
            validDays: coupon.validDays,
            categoryIds: coupon.categoryIds,
            productIds: coupon.productIds,
            isActive: false,
            createdAt: coupon.createdAt,
            updatedAt: DateTime.now(),
          );
          await _dbService.updateCoupon(coupon.id!, updated);
          needRefresh = true;
        }
      }

      final finalCoupons = needRefresh ? await _dbService.getAllCoupons() : coupons;
      final userCoupons = await _dbService.getAllUserCoupons();

      if (mounted) {
        setState(() {
          _coupons = finalCoupons;
          _userCoupons = userCoupons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _coupons = [];
          _userCoupons = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Coupon> get _filteredCoupons {
    switch (_statusFilter) {
      case '进行中':
        return _coupons.where((c) => c.isActive).toList();
      case '已结束':
        return _coupons.where((c) => !c.isActive).toList();
      default:
        return _coupons;
    }
  }

  String _getCouponStatusText(Coupon coupon) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (coupon.isActive) return '进行中';
    if (coupon.endTime != null && coupon.endTime!.millisecondsSinceEpoch < now) return '已过期';
    if (coupon.endTime == null && coupon.validDays != null) return '已结束';
    if (coupon.endTime == null && coupon.validDays == null) return '已结束';
    return '已结束';
  }

  Color _getStatusColor(Coupon coupon, ThemeData theme) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (coupon.isActive) return theme.colorScheme.primary;
    if (coupon.endTime != null && coupon.endTime!.millisecondsSinceEpoch < now) return theme.colorScheme.error;
    return theme.colorScheme.onSurfaceVariant;
  }

  String _generateCouponCode() {
    final now = DateTime.now();
    return 'CP${now.millisecondsSinceEpoch}${now.microsecond.toString().padLeft(3, '0')}';
  }

  void _showCreateCouponDialog() {
    final theme = ref.watch(currentThemeProvider);
    String name = '';
    String type = 'fixed';
    String rewardType = 'cash';
    double amount = 0;
    double discount = 0.9;
    double condition = 0;
    int totalCount = 100;
    DateTime validity = DateTime.now().add(const Duration(days: 30));
    String validityMode = 'fixed';
    int validDaysInput = 30;

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
                    items: const [
                      DropdownMenuItem(value: 'fixed', child: Text('满减券')),
                      DropdownMenuItem(value: 'percentage', child: Text('折扣券')),
                      DropdownMenuItem(value: 'shipping', child: Text('运费券')),
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
                  if (type == 'fixed')
                    TextField(
                      decoration: InputDecoration(
                        labelText: '优惠金额',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixText: rewardType == 'points' ? '积分' : '¥',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => amount = double.tryParse(value) ?? 0,
                    ),
                  if (type == 'percentage')
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => discount = (double.tryParse(value) ?? 9) / 10,
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '使用门槛（0为无门槛）',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      prefixText: rewardType == 'points' ? '积分' : '¥',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => totalCount = int.tryParse(value) ?? 100,
                  ),
                  const SizedBox(height: 16),
                  Text('有效期模式', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fixed', label: Text('固定日期')),
                      ButtonSegment(value: 'after_claim', label: Text('领取后N天')),
                      ButtonSegment(value: 'permanent', label: Text('永久有效')),
                    ],
                    selected: {validityMode},
                    onSelectionChanged: (selection) => setDialogState(() => validityMode = selection.first),
                  ),
                  const SizedBox(height: 16),
                  if (validityMode == 'fixed')
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: validity,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
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
                  if (validityMode == 'after_claim')
                    TextField(
                      decoration: InputDecoration(
                        labelText: '领取后有效天数',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        suffixText: '天',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => validDaysInput = int.tryParse(value) ?? 30,
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
                      content: Text('请输入优惠券名称', style: TextStyle(color: theme.colorScheme.onError)),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }

                final couponType = type;
                final couponValue = type == 'fixed'
                    ? (rewardType == 'points' ? amount.round() : (amount * 100).round())
                    : type == 'percentage'
                        ? (discount * 100).round()
                        : 0;

                final coupon = Coupon(
                  name: name,
                  code: _generateCouponCode(),
                  type: couponType,
                  rewardType: rewardType,
                  value: couponValue,
                  minAmount: rewardType == 'points' ? condition.round() : (condition * 100).round(),
                  totalCount: totalCount,
                  usedCount: 0,
                  startTime: DateTime.now(),
                  endTime: validityMode == 'fixed' ? DateTime(validity.year, validity.month, validity.day, 23, 59, 59) : null,
                  validDays: validityMode == 'after_claim' ? validDaysInput : null,
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await _dbService.insertCoupon(coupon);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('优惠券创建成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                  _loadData();
                }
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

  void _showDistributeDialog(Coupon coupon) {
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
          title: Text('发放优惠券 - ${coupon.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
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
                Navigator.pop(context);

                final expiresAt = coupon.endTime ?? (coupon.validDays != null ? DateTime.now().add(Duration(days: coupon.validDays!)) : null);
                final userDbService = UserDatabaseService();
                final personalDbService = DatabaseService();
                final expiresAtMs = expiresAt?.millisecondsSinceEpoch;

                if (distributeType == 'all') {
                  final userCoupon = UserCoupon(
                    userId: 'all',
                    couponId: coupon.id!,
                    createdAt: DateTime.now(),
                    expiresAt: expiresAt,
                    status: 'unused',
                  );
                  for (var i = 0; i < count; i++) {
                    await _dbService.insertUserCoupon(userCoupon);
                  }
                  for (var i = 0; i < count; i++) {
                    await personalDbService.insertUserCoupon({
                      'user_id': 'all',
                      'coupon_id': coupon.id!,
                      'status': 'unused',
                      'created_at': DateTime.now().millisecondsSinceEpoch,
                      'expires_at': expiresAtMs,
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
                    final userCoupon = UserCoupon(
                      userId: userId,
                      couponId: coupon.id!,
                      createdAt: DateTime.now(),
                      expiresAt: expiresAt,
                      status: 'unused',
                    );
                    for (var i = 0; i < count; i++) {
                      await _dbService.insertUserCoupon(userCoupon);
                    }
                    for (var i = 0; i < count; i++) {
                      await personalDbService.insertUserCoupon({
                        'user_id': userId,
                        'coupon_id': coupon.id!,
                        'status': 'unused',
                        'created_at': DateTime.now().millisecondsSinceEpoch,
                        'expires_at': expiresAtMs,
                      });
                    }
                  }
                }

                final updatedCoupon = Coupon(
                  id: coupon.id,
                  name: coupon.name,
                  code: coupon.code,
                  type: coupon.type,
                  rewardType: coupon.rewardType,
                  value: coupon.value,
                  minAmount: coupon.minAmount,
                  maxDiscount: coupon.maxDiscount,
                  totalCount: coupon.totalCount,
                  usedCount: coupon.usedCount + (count * (distributeType == 'all' ? 1 : selectedUserIds.length)),
                  startTime: coupon.startTime,
                  endTime: coupon.endTime,
                  validDays: coupon.validDays,
                  categoryIds: coupon.categoryIds,
                  productIds: coupon.productIds,
                  isActive: coupon.isActive,
                  createdAt: coupon.createdAt,
                  updatedAt: DateTime.now(),
                );
                await _dbService.updateCoupon(coupon.id!, updatedCoupon);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('优惠券发放成功', style: TextStyle(color: theme.colorScheme.onPrimary)),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                  _loadData();
                }
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

  void _showEndActivityDialog(Coupon coupon) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('结束活动', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: Text('确定要结束优惠券「${coupon.name}」的活动吗？结束后用户将无法继续领取。', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Coupon(
                id: coupon.id,
                name: coupon.name,
                code: coupon.code,
                type: coupon.type,
                value: coupon.value,
                minAmount: coupon.minAmount,
                maxDiscount: coupon.maxDiscount,
                totalCount: coupon.totalCount,
                usedCount: coupon.usedCount,
                startTime: coupon.startTime,
                endTime: coupon.endTime,
                validDays: coupon.validDays,
                categoryIds: coupon.categoryIds,
                productIds: coupon.productIds,
                isActive: false,
                createdAt: coupon.createdAt,
                updatedAt: DateTime.now(),
              );
              await _dbService.updateCoupon(coupon.id!, updated);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('活动已结束', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Coupon coupon) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('删除优惠券', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: Text('确定要删除优惠券「${coupon.name}」吗？删除后不可恢复！', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _dbService.deleteCoupon(coupon.id!);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('优惠券已删除', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog(Coupon coupon) {
    final theme = ref.watch(currentThemeProvider);
    final usageRate = coupon.totalCount > 0 ? (coupon.usedCount / coupon.totalCount * 100).toStringAsFixed(1) : '0.0';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.background,
        title: Text('优惠券统计 - ${coupon.name}', style: TextStyle(color: theme.colorScheme.onBackground)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('总发放', '${coupon.totalCount}', theme.colorScheme.primary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('已使用', '${coupon.usedCount}', theme.colorScheme.secondary, theme),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('剩余', '${coupon.totalCount - coupon.usedCount}', theme.colorScheme.tertiary, theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('使用率', '$usageRate%', theme.colorScheme.error, theme),
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
    final filtered = _filteredCoupons;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: ['全部', '进行中', '已结束'].map((filter) {
              final isSelected = _statusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _statusFilter = filter);
                    }
                  },
                  selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '暂无优惠券',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final coupon = filtered[index];
                      return _buildCouponCard(coupon, theme);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCouponCard(Coupon coupon, ThemeData theme) {
    final statusText = _getCouponStatusText(coupon);
    final statusColor = _getStatusColor(coupon, theme);

    String valueDisplay;
    if (coupon.type == 'percentage') {
      valueDisplay = '${((coupon.value ?? 0) / 10).toStringAsFixed(0)}折';
    } else if (coupon.type == 'shipping') {
      valueDisplay = '免运费';
    } else {
      if (coupon.rewardType == 'points') {
        valueDisplay = '${coupon.value ?? 0}积分';
      } else {
        valueDisplay = '¥${((coupon.value ?? 0) / 100).toStringAsFixed(2)}';
      }
    }

    String conditionDisplay;
    if ((coupon.minAmount ?? 0) > 0) {
      if (coupon.rewardType == 'points') {
        conditionDisplay = '满${coupon.minAmount!}可用';
      } else {
        conditionDisplay = '满${(coupon.minAmount! / 100).toStringAsFixed(0)}可用';
      }
    } else {
      conditionDisplay = '无门槛使用';
    }

    String typeDisplay;
    switch (coupon.type) {
      case 'percentage':
        typeDisplay = '折扣券';
        break;
      case 'shipping':
        typeDisplay = '运费券';
        break;
      default:
        typeDisplay = '满减券';
    }

    final rewardTypeDisplay = coupon.rewardType == 'points' ? '积分券' : '现金券';

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
                      coupon.name,
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
                children: [
                  Text(
                    valueDisplay,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$typeDisplay · $conditionDisplay',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: coupon.rewardType == 'points'
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rewardTypeDisplay,
                      style: TextStyle(
                        color: coupon.rewardType == 'points' ? Colors.amber.shade700 : Colors.green.shade700,
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
                    '已使用: ${coupon.usedCount}/${coupon.totalCount}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '有效期: ${coupon.endTime != null ? coupon.endTime!.toString().substring(0, 10) : coupon.validDays != null ? '领取后${coupon.validDays}天' : '永久有效'}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (coupon.isActive)
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
                  if (coupon.isActive) const SizedBox(width: 8),
                  if (coupon.isActive)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEndActivityDialog(coupon),
                        icon: const Icon(Icons.stop_circle, size: 18),
                        label: const Text('结束活动'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  if (!coupon.isActive) ...[
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteDialog(coupon),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                  if (coupon.isActive) ...[
                    const SizedBox(width: 8),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributeRecords(ThemeData theme) {
    if (_userCoupons.isEmpty) {
      return Center(
        child: Text(
          '暂无发放记录',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _userCoupons.length,
        itemBuilder: (context, index) {
          final record = _userCoupons[index];
          final statusMap = {'unused': '未使用', 'used': '已使用', 'expired': '已过期'};
          final statusText = statusMap[record.status] ?? record.status;

          return FutureBuilder<Coupon?>(
            future: _dbService.getCouponById(record.couponId),
            builder: (context, snapshot) {
              final couponName = snapshot.data?.name ?? '优惠券#${record.couponId}';

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                couponName,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: record.status == 'unused'
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : record.status == 'used'
                                        ? theme.colorScheme.tertiary.withOpacity(0.2)
                                        : theme.colorScheme.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: record.status == 'unused'
                                      ? theme.colorScheme.primary
                                      : record.status == 'used'
                                          ? theme.colorScheme.tertiary
                                          : theme.colorScheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '用户: ${record.userId}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.confirmation_number, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '券ID: ${record.couponId}',
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
                              '发放: ${record.createdAt.toString().substring(0, 16)}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            if (record.expiresAt != null) ...[
                              Icon(Icons.event_busy, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '过期: ${record.expiresAt!.toString().substring(0, 10)}',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
