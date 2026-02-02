import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/services/database_service.dart';

class CouponsDetailPage extends ConsumerStatefulWidget {
  final String? userId;
  final bool selectMode;
  final String? selectType; // 'coupon' or 'red_packet'
  final List<Map<String, dynamic>>? selectedRedPackets; // 已选中的红包列表
  final List<Map<String, dynamic>>? selectedCoupons; // 已选中的优惠券列表
  
  const CouponsDetailPage({super.key, this.userId, this.selectMode = false, this.selectType, this.selectedRedPackets, this.selectedCoupons});

  @override
  ConsumerState<CouponsDetailPage> createState() => _CouponsDetailPageState();
}

class _CouponsDetailPageState extends ConsumerState<CouponsDetailPage> with SingleTickerProviderStateMixin {
  // 标签控制器
  late TabController _tabController;

  // 真实数据状态
  List<Map<String, dynamic>> _availableCoupons = [];
  List<Map<String, dynamic>> _usedCoupons = [];
  List<Map<String, dynamic>> _availableRedPackets = [];
  List<Map<String, dynamic>> _usedRedPackets = [];
  bool _isLoading = true;
  
  // 选中的红包列表（用于多选模式）
  List<Map<String, dynamic>> _selectedRedPackets = [];
  // 选中的优惠券列表（用于多选模式）
  List<Map<String, dynamic>> _selectedCoupons = [];

  @override
  void initState() {
    super.initState();
    // 根据selectType设置标签控制器长度
    final tabLength = widget.selectType != null ? 1 : 3;
    _tabController = TabController(length: tabLength, vsync: this);
    // 初始化已选中的红包列表
    if (widget.selectedRedPackets != null) {
      _selectedRedPackets = widget.selectedRedPackets!;
    }
    // 初始化已选中的优惠券列表
    if (widget.selectedCoupons != null) {
      _selectedCoupons = widget.selectedCoupons!;
    }
    // 延迟加载数据，避免在构建过程中调用异步方法
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCouponsData();
    });
  }
  
  // 检查并更新优惠券和红包的状态
  void _checkAndUpdateStatus(List<Map<String, dynamic>> coupons, List<Map<String, dynamic>> redPackets) {
    final now = DateTime.now();
    
    // 更新优惠券状态并分类
    _availableCoupons = [];
    _usedCoupons = [];
    for (var coupon in coupons) {
      final updatedCoupon = Map<String, dynamic>.from(coupon);
      final validityDate = DateTime.tryParse(updatedCoupon['validity']);
      if (validityDate != null && validityDate.isBefore(now) && updatedCoupon['status'] == '可用') {
        updatedCoupon['status'] = '已过期';
      }
      // 分类：可用状态的优惠券放入可用列表，其他放入已使用/过期列表
      if (updatedCoupon['status'] == '可用') {
        _availableCoupons.add(updatedCoupon);
      } else {
        _usedCoupons.add(updatedCoupon);
      }
    }
    
    // 更新红包状态并分类
    _availableRedPackets = [];
    _usedRedPackets = [];
    for (var redPacket in redPackets) {
      final updatedRedPacket = Map<String, dynamic>.from(redPacket);
      final validityDate = DateTime.tryParse(updatedRedPacket['validity']);
      if (validityDate != null && validityDate.isBefore(now) && updatedRedPacket['status'] == '可用') {
        updatedRedPacket['status'] = '已过期';
      }
      // 分类：可用状态的红包放入可用列表，其他放入已使用/过期列表
      if (updatedRedPacket['status'] == '可用') {
        _availableRedPackets.add(updatedRedPacket);
      } else {
        _usedRedPackets.add(updatedRedPacket);
      }
    }
  }
  
  // 加载优惠券和红包数据
  Future<void> _loadCouponsData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 使用从构造函数传递过来的userId，如果为null则使用默认值
      final userId = widget.userId ?? 'default_user';
      debugPrint('使用的用户ID: $userId');
      
      // 从数据库获取真实优惠券数据
      final databaseService = DatabaseService();
      final coupons = await databaseService.getUserCoupons(userId);
      
      // 从数据库获取真实红包数据
      final redPackets = await databaseService.getUserRedPackets(userId);
      
      // 检查并更新优惠券和红包的状态，同时分类为可用和已使用
      _checkAndUpdateStatus(coupons, redPackets);
      
      // 如果没有数据，初始化一些模拟数据用于测试
      if (_availableCoupons.isEmpty && _usedCoupons.isEmpty) {
        final mockCoupons = [
          {
            'id': '1',
            'name': '满100减20优惠券',
            'amount': 20,
            'condition': 100,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '满减券',
            'user_id': userId,
            'discount': 1.0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '2',
            'name': '全场9折优惠券',
            'amount': 0,
            'condition': 0,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '折扣券',
            'discount': 0.9,
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '3',
            'name': '全场8折优惠券',
            'amount': 0,
            'condition': 0,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '折扣券',
            'discount': 0.8,
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        // 保存模拟数据到数据库
        for (var coupon in mockCoupons) {
          await databaseService.database.then((db) async {
            await db.insert('coupons', coupon);
          });
        }
        _availableCoupons = mockCoupons;
      }
      
      if (_availableRedPackets.isEmpty && _usedRedPackets.isEmpty) {
        final mockRedPackets = [
          {
            'id': '1',
            'name': '新人红包',
            'amount': 10,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '现金红包',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '2',
            'name': '生日红包',
            'amount': 50,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '现金红包',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        // 保存模拟数据到数据库
        for (var redPacket in mockRedPackets) {
          await databaseService.database.then((db) async {
            await db.insert('red_packets', redPacket);
          });
        }
        _availableRedPackets = mockRedPackets;
      }
    } catch (e) {
      debugPrint('加载优惠券数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text('优惠券 / 红包', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        actions: widget.selectMode ? [
          TextButton(
            onPressed: () {
              if (widget.selectType == 'red_packet') {
                Navigator.pop(context, _selectedRedPackets);
              } else {
                Navigator.pop(context, _selectedCoupons);
              }
            },
            child: Text('确认', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ] : [],
        bottom: widget.selectType != null ? null : PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 3,
              tabs: [
                Tab(text: '优惠券 (${_availableCoupons.length})'),
                Tab(text: '红包 (${_availableRedPackets.length})'),
                Tab(text: '已失效 (${_usedCoupons.length + _usedRedPackets.length})'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading ? _buildLoadingState(theme) : TabBarView(
        controller: _tabController,
        children: widget.selectType == 'red_packet' 
          ? [_buildRedPacketsList(theme)] 
          : widget.selectType == 'coupon' 
            ? [_buildCouponsList(theme)]
            : [
                // 优惠券列表
                _buildCouponsList(theme),
                // 红包列表
                _buildRedPacketsList(theme),
                // 已失效列表
                _buildInvalidList(theme),
              ],
      ),
    );
  }

  // 构建加载状态
  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '加载优惠券数据中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建优惠券列表
  Widget _buildCouponsList(ThemeData theme) {
    return _availableCoupons.isEmpty
        ? _buildEmptyState('暂无优惠券', Icons.local_offer, theme)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _availableCoupons.length,
            itemBuilder: (context, index) {
              final coupon = _availableCoupons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCouponItem(coupon, theme),
              );
            },
          );
  }

  // 构建红包列表
  Widget _buildRedPacketsList(ThemeData theme) {
    return _availableRedPackets.isEmpty
        ? _buildEmptyState('暂无红包', Icons.monetization_on, theme)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _availableRedPackets.length,
            itemBuilder: (context, index) {
              final redPacket = _availableRedPackets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildRedPacketItem(redPacket, theme),
              );
            },
          );
  }

  // 构建已失效列表
  Widget _buildInvalidList(ThemeData theme) {
    final allInvalidItems = [..._usedCoupons, ..._usedRedPackets];
    return allInvalidItems.isEmpty
        ? _buildEmptyState('暂无已失效的优惠券/红包', Icons.history, theme)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allInvalidItems.length,
            itemBuilder: (context, index) {
              final item = allInvalidItems[index];
              // 根据类型构建不同的item
              if (item.containsKey('discount') || item['type'] == '满减券' || item['type'] == '折扣券') {
                // 优惠券
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCouponItem(item, theme),
                );
              } else {
                // 红包
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildRedPacketItem(item, theme),
                );
              }
            },
          );
  }
  
  // 构建空状态
  Widget _buildEmptyState(String message, IconData icon, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurfaceVariant,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // 构建溯源信息
  Widget _buildTraceabilityInfo(Map<String, dynamic> item, ThemeData theme) {
    final fromUserName = item['from_user_name'] as String?;
    final reason = item['reason'] as String?;
    final usedAt = item['used_at'] as int?;
    final usedOrderId = item['used_order_id'] as String?;
    
    if ((fromUserName == null || fromUserName.isEmpty) && (reason == null || reason.isEmpty)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '溯源信息',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (fromUserName != null && fromUserName.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.person_outline, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '来源: $fromUserName',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (reason != null && reason.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.note_outlined, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '原因: $reason',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (usedAt != null) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '使用时间: ${DateTime.fromMillisecondsSinceEpoch(usedAt).toString().substring(0, 19)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (usedOrderId != null && usedOrderId.isNotEmpty) 
            Row(
              children: [
                Icon(Icons.receipt_outlined, 
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '使用订单: $usedOrderId',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 构建优惠券项
  Widget _buildCouponItem(Map<String, dynamic> coupon, ThemeData theme) {
    final isAvailable = coupon['status'] == '可用';
    final isSelected = _selectedCoupons.any((item) => item['id'] == coupon['id']);
    return GestureDetector(
      onTap: () {
        if (isAvailable && widget.selectMode) {
          // 多选模式：切换选择状态
          setState(() {
            if (isSelected) {
              _selectedCoupons.removeWhere((item) => item['id'] == coupon['id']);
            } else {
              // 检查优惠券互斥性
              // 满减券与满减券互斥，折扣券与折扣券互斥
              if (coupon['type'] == '满减券') {
                // 移除其他满减券
                _selectedCoupons.removeWhere((item) => item['type'] == '满减券');
              } else if (coupon['type'] == '折扣券') {
                // 移除其他折扣券
                _selectedCoupons.removeWhere((item) => item['type'] == '折扣券');
              }
              // 添加当前优惠券
              _selectedCoupons.add(coupon);
            }
          });
        } else {
          // 显示交易记录
          _showTransactionHistory(coupon, 'coupon');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 优惠券名称和状态
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      coupon['name'],
                      style: TextStyle(
                        color: isAvailable ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      if (widget.selectMode && isAvailable) 
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                // 检查优惠券互斥性
                                // 满减券与满减券互斥，折扣券与折扣券互斥
                                if (coupon['type'] == '满减券') {
                                  // 移除其他满减券
                                  _selectedCoupons.removeWhere((item) => item['type'] == '满减券');
                                } else if (coupon['type'] == '折扣券') {
                                  // 移除其他折扣券
                                  _selectedCoupons.removeWhere((item) => item['type'] == '折扣券');
                                }
                                // 添加当前优惠券
                                _selectedCoupons.add(coupon);
                              } else {
                                _selectedCoupons.removeWhere((item) => item['id'] == coupon['id']);
                              }
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAvailable 
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          coupon['status'],
                          style: TextStyle(
                            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 优惠金额和使用条件
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (coupon['type'] == '折扣券')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(coupon['discount'] * 10).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '折',
                          style: TextStyle(
                            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '¥${coupon['amount']}',
                      style: TextStyle(
                        color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      coupon['condition'] > 0 
                          ? '满${coupon['condition']}可用' 
                          : '无门槛使用',
                      style: TextStyle(
                        color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 有效期和类型
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '有效期至: ${coupon['validity']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    coupon['type'],
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 溯源信息
              _buildTraceabilityInfo(coupon, theme),
              const SizedBox(height: 16),
              
              // 立即使用按钮
              if (!widget.selectMode)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isAvailable ? () {
                      _showNotImplemented();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      foregroundColor: isAvailable ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      ),
                      elevation: isAvailable ? 2 : 0,
                    ),
                    child: Text('立即使用'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建红包项
  Widget _buildRedPacketItem(Map<String, dynamic> redPacket, ThemeData theme) {
    final isAvailable = redPacket['status'] == '可用';
    final isSelected = _selectedRedPackets.any((item) => item['id'] == redPacket['id']);
    return GestureDetector(
      onTap: () {
        if (isAvailable) {
          if (widget.selectMode && widget.selectType == 'red_packet') {
            // 多选模式：切换选择状态
            setState(() {
              if (isSelected) {
                _selectedRedPackets.removeWhere((item) => item['id'] == redPacket['id']);
              } else {
                _selectedRedPackets.add(redPacket);
              }
            });
          } else if (widget.selectMode) {
            // 单选模式：直接返回
            Navigator.pop(context, redPacket);
          } else {
            // 显示交易记录
            _showTransactionHistory(redPacket, 'red_packet');
          }
        } else {
          // 已使用或过期的红包也可以查看交易记录
          _showTransactionHistory(redPacket, 'red_packet');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? theme.colorScheme.error : theme.colorScheme.outlineVariant,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 红包名称和状态
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      redPacket['name'],
                      style: TextStyle(
                        color: isAvailable ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      if (widget.selectMode && widget.selectType == 'red_packet' && isAvailable) 
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedRedPackets.add(redPacket);
                              } else {
                                _selectedRedPackets.removeWhere((item) => item['id'] == redPacket['id']);
                              }
                            });
                          },
                          activeColor: theme.colorScheme.error,
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAvailable 
                              ? theme.colorScheme.error.withOpacity(0.2)
                              : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          redPacket['status'],
                          style: TextStyle(
                            color: isAvailable ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 红包金额
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    redPacket['type'] == '积分红包' || redPacket['type'] == '星星红包' ? '✨' : '¥',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${redPacket['amount']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 红包类型
              Text(
                redPacket['type'],
                style: TextStyle(
                  color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // 有效期
              Text(
                '有效期至: ${redPacket['validity']}',
                style: TextStyle(
                  color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              
              // 溯源信息
              _buildTraceabilityInfo(redPacket, theme),
              const SizedBox(height: 16),
              
              // 立即使用按钮
              if (!(widget.selectMode && widget.selectType == 'red_packet'))
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isAvailable ? () {
                      if (widget.selectMode) {
                        // 返回选中的红包
                        Navigator.pop(context, redPacket);
                      } else {
                        _showNotImplemented();
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable ? theme.colorScheme.error : theme.colorScheme.outlineVariant,
                      foregroundColor: isAvailable ? theme.colorScheme.onError : theme.colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? theme.colorScheme.onError : theme.colorScheme.onSurfaceVariant,
                      ),
                      elevation: isAvailable ? 2 : 0,
                    ),
                    child: Text(widget.selectMode ? '选择' : '立即使用'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 显示功能未实现提示
  void _showNotImplemented() {
    final theme = ref.watch(currentThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('该功能尚未实现', style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 显示交易记录
  void _showTransactionHistory(Map<String, dynamic> item, String type) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('交易记录', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTransactionHistory(item['id'], item['name'], type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('加载交易记录失败', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Center(
                    child: Text('暂无交易记录', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionItem(transaction, theme);
                  },
                );
              },
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

  // 获取交易记录
  Future<List<Map<String, dynamic>>> _getTransactionHistory(String itemId, String itemName, String type) async {
    final databaseService = DatabaseService();
    final userId = widget.userId ?? 'default_user';
    final billItems = await databaseService.getBillItems(
      userId,
    );
    // 转换BillItem为Map，并过滤出与当前优惠券/红包相关的交易记录
    return billItems
        .where((item) {
          // 检查交易描述中是否包含当前优惠券/红包的ID
          if (type == 'coupon') {
            // 只匹配包含当前优惠券ID的交易记录
            return item.description.contains('优惠券:') && item.description.contains(itemId);
          } else if (type == 'red_packet') {
            // 只匹配包含当前红包ID的交易记录
            return item.description.contains('红包:') && item.description.contains(itemId);
          }
          return false;
        })
        .map((item) => {
          'id': item.id,
          'description': item.description,
          'amount': item.amount,
          'type': item.type,
          'transactionType': item.transactionType,
          'created_at': item.createdAt.millisecondsSinceEpoch,
          'relatedId': item.relatedId,
        })
        .toList();
  }

  // 构建交易记录项
  Widget _buildTransactionItem(Map<String, dynamic> transaction, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction['description'] ?? '无描述',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '✨${transaction['transactionType'] == '收入' ? '+' : '-' }${transaction['amount']}',
                  style: TextStyle(
                    color: transaction['transactionType'] == '收入' 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${transaction['type']} | ${DateTime.fromMillisecondsSinceEpoch(transaction['created_at']).toString().substring(0, 19)}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}