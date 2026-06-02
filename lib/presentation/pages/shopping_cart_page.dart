import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/presentation/components/user_points_provider.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';
import 'package:moment_keep/presentation/pages/payment_result_page.dart';

class ShoppingCartPage extends ConsumerStatefulWidget {
  const ShoppingCartPage({super.key});

  @override
  ConsumerState<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends ConsumerState<ShoppingCartPage> {
  // 真实购物车数据
  List<CartItem> _cartItems = [];
  final DatabaseService _databaseService = DatabaseService();
  final ProductDatabaseService _productDatabaseService = ProductDatabaseService();
  bool _isLoading = true;

  // 商品有效性状态跟踪
  Map<int, bool> _validItemIds = {};
  Map<int, String> _invalidReasons = {};

  // 当前选择的支付方式
  PaymentMethod _selectedPaymentMethod = PaymentMethod.points;
  
  // 商品选择状态管理 - 存储选中的商品ID
  Set<int> _selectedItemIds = {};
  // 全选状态
  bool _isAllSelected = false;
  bool _isProcessing = false;

  // 商家分组选择状态 - merchantId -> 该组内选中的商品ID集合
  Map<int?, Set<int>> _groupSelectedIds = {};

  // 优惠券和红包状态
  List<Map<String, dynamic>> _availableCoupons = [];
  List<Map<String, dynamic>> _availableRedPackets = [];
  List<Map<String, dynamic>> _selectedCoupons = [];
  List<Map<String, dynamic>> _selectedRedPackets = [];

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  // 从数据库加载购物车数据
  Future<void> _loadCartItems() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      final items = await _databaseService.getCartItems(userId);
      
      final validItemIds = <int, bool>{};
      final invalidReasons = <int, String>{};
      
      for (final item in items) {
        final product = item.product;
        if (product.isDeleted == true) {
          invalidReasons[item.id] = '已删除';
          validItemIds[item.id] = false;
        } else if (product.isActive == false) {
          invalidReasons[item.id] = '已下架';
          validItemIds[item.id] = false;
        } else if (product.stock <= 0) {
          invalidReasons[item.id] = '已售罄';
          validItemIds[item.id] = false;
        } else {
          validItemIds[item.id] = true;
        }
      }
      
      final coupons = await _databaseService.getUserCoupons(userId);
      final availableCoupons = coupons.where((c) => c['status'] == '可用').toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      final validCoupons = availableCoupons.where((c) {
        final expiresAt = c['expires_at'] as int?;
        return expiresAt == null || expiresAt > now;
      }).toList();
      
      final redPackets = await _databaseService.getUserRedPackets(userId);
      final availableRedPackets = redPackets.where((rp) => rp['status'] == '可用').toList();
      
      setState(() {
        _cartItems = items;
        _validItemIds = validItemIds;
        _invalidReasons = invalidReasons;
        _availableCoupons = validCoupons;
        _availableRedPackets = availableRedPackets;
        _isLoading = false;
      });
      
      for (final entry in invalidReasons.entries) {
        _selectedItemIds.remove(entry.key);
      }
      
      _updateSelectAllStatus();
      _updateGroupSelectedIds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载购物车失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateSelectAllStatus() {
    final validItems = _cartItems.where((item) => _validItemIds[item.id] == true).toList();
    if (validItems.isEmpty) {
      _isAllSelected = false;
    } else {
      _isAllSelected = validItems.every((item) => _selectedItemIds.contains(item.id));
    }
  }

  /// 更新商家分组选择状态
  void _updateGroupSelectedIds() {
    _groupSelectedIds = {};
    for (final entry in _groupedCartItems.entries) {
      final merchantId = entry.key;
      final items = entry.value;
      final validItemIdsInGroup = items.where((item) => _validItemIds[item.id] == true).map((item) => item.id).toSet();
      final selectedInGroup = validItemIdsInGroup.where((id) => _selectedItemIds.contains(id)).toSet();
      _groupSelectedIds[merchantId] = selectedInGroup;
    }
  }

  /// 检查商家分组是否全选
  bool _isGroupAllSelected(int? merchantId) {
    final groupItems = _groupedCartItems[merchantId] ?? [];
    final validItems = groupItems.where((item) => _validItemIds[item.id] == true).toList();
    if (validItems.isEmpty) return false;
    return validItems.every((item) => _selectedItemIds.contains(item.id));
  }

  /// 商家分组全选/取消全选
  void _toggleGroupSelectAll(int? merchantId, bool? value) {
    final groupItems = _groupedCartItems[merchantId] ?? [];
    final validItems = groupItems.where((item) => _validItemIds[item.id] == true).toList();
    final validIds = validItems.map((item) => item.id).toSet();
    
    setState(() {
      if (value == true) {
        _selectedItemIds.addAll(validIds);
      } else {
        _selectedItemIds.removeAll(validIds);
      }
      _updateSelectAllStatus();
      _updateGroupSelectedIds();
    });
  }

  /// 计算分组后的总行数（不含全选行）
  int _buildGroupedItemCount() {
    int count = 0;
    for (final entry in _groupedCartItems.entries) {
      count += 1; // header
      count += entry.value.length; // items
    }
    return count;
  }

  /// 根据索引获取分组信息
  Map<String, dynamic>? _getGroupInfoByIndex(int index) {
    int currentIndex = 0;
    for (final entry in _groupedCartItems.entries) {
      if (currentIndex == index) {
        return {'isHeader': true, 'merchantId': entry.key};
      }
      currentIndex++;
      for (int i = 0; i < entry.value.length; i++) {
        if (currentIndex == index) {
          return {'isHeader': false, 'item': entry.value[i], 'merchantId': entry.key, 'itemIndex': i};
        }
        currentIndex++;
      }
    }
    return null;
  }

  /// 构建商家分组头部
  Widget _buildGroupHeader(int? merchantId) {
    final groupName = merchantId == null ? '其他商家' : '商家ID: $merchantId';
    final isAllSelected = _isGroupAllSelected(merchantId);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: isAllSelected,
            onChanged: (bool? value) {
              _toggleGroupSelectAll(merchantId, value);
            },
            activeColor: const Color(0xFF13ec5b),
            checkColor: Colors.black,
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.storefront,
            size: 20,
            color: const Color(0xFF13ec5b),
          ),
          const SizedBox(width: 8),
          Text(
            groupName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_groupedCartItems[merchantId]?.length ?? 0}件商品',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 获取选中的购物车商品
  List<CartItem> get _selectedItems {
    return _cartItems.where((item) => _selectedItemIds.contains(item.id)).toList();
  }

  // 按商家分组的购物车商品
  Map<int?, List<CartItem>> get _groupedCartItems {
    final groups = <int?, List<CartItem>>{};
    for (final item in _cartItems) {
      final merchantId = item.product.merchantId;
      groups.putIfAbsent(merchantId, () => []);
      groups[merchantId]!.add(item);
    }
    return groups;
  }

  // 优惠券抵扣金额
  int get _couponDiscount {
    int discount = 0;
    for (final coupon in _selectedCoupons) {
      final rewardType = coupon['reward_type'] ?? 'cash';
      if (rewardType == 'cash') {
        final couponType = coupon['type'] ?? '';
        if (couponType == '满减券' || couponType == '无门槛券' || couponType == '星星券') {
          discount += (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
        }
      }
    }
    return discount;
  }

  // 红包抵扣金额
  int get _redPacketDiscount {
    int discount = 0;
    for (final rp in _selectedRedPackets) {
      final rewardType = rp['reward_type'] ?? 'cash';
      if (rewardType == 'cash') {
        discount += (rp['amount'] is num ? (rp['amount'] as num).toInt() : 0);
      }
    }
    return discount;
  }

  // 实际应付金额（现金部分）
  int get _actualPayableCash {
    final base = _totalCash - _couponDiscount - _redPacketDiscount;
    return base > 0 ? base : 0;
  }

  // 计算不同支付方式的总价 - 与星星商店页保持一致，直接使用原始价格值，只计算选中商品
  int get _totalPoints {
    return _selectedItems.fold(0, (sum, item) => sum + (item.product.points * item.quantity));
  }

  int get _totalCash {
    return _selectedItems.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  // 混合支付的总价（积分+现金） - 与星星商店页保持一致，添加默认值处理，只计算选中商品
  Map<String, dynamic> get _totalHybrid {
    return {
      'points': _selectedItems.fold(0, (sum, item) {
        // 为每个商品添加默认值处理
        final hybridPoints = item.product.hybridPoints > 0 ? item.product.hybridPoints : item.product.points ~/ 2;
        return sum + (hybridPoints * item.quantity);
      }),
      'cash': _selectedItems.fold(0, (sum, item) {
        // 为每个商品添加默认值处理
        final hybridPrice = item.product.hybridPrice > 0 ? item.product.hybridPrice : item.product.price ~/ 2;
        return sum + (hybridPrice * item.quantity);
      }),
    };
  }

  // 调整商品数量
  Future<void> _adjustQuantity(int index, int delta) async {
    try {
      final item = _cartItems[index];
      final newQuantity = item.quantity + delta;
      if (newQuantity >= 1) {
        await _databaseService.updateCartItemQuantity(item.id, newQuantity);
        await _loadCartItems();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('调整数量失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 删除商品
  Future<void> _removeItem(int index) async {
    try {
      final item = _cartItems[index];
      await _databaseService.removeFromCart(item.id);
      await _loadCartItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除商品失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 清空购物车
  Future<void> _clearCart() async {
    try {
      await _databaseService.clearCart();
      await _loadCartItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清空购物车失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 显示支付对话框
  Future<void> _showPaymentDialog() async {
    bool isPaymentMethodSupported(PaymentMethod method) {
      for (var cartItem in _selectedItems) {
        final product = cartItem.product;
        switch (method) {
          case PaymentMethod.points:
            if (!product.supportPointsPayment) return false;
            break;
          case PaymentMethod.cash:
            if (!product.supportCashPayment) return false;
            break;
          case PaymentMethod.hybrid:
            if (!product.supportHybridPayment) return false;
            break;
          case PaymentMethod.shoppingCard:
            break;
        }
      }
      return true;
    }

    if (!isPaymentMethodSupported(_selectedPaymentMethod)) {
      if (isPaymentMethodSupported(PaymentMethod.cash)) {
        _selectedPaymentMethod = PaymentMethod.cash;
      } else if (isPaymentMethodSupported(PaymentMethod.points)) {
        _selectedPaymentMethod = PaymentMethod.points;
      } else if (isPaymentMethodSupported(PaymentMethod.hybrid)) {
        _selectedPaymentMethod = PaymentMethod.hybrid;
      }
    }

    PaymentMethod dialogSelectedPayment = _selectedPaymentMethod;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final discount = _couponDiscount + _redPacketDiscount;
            final hasDiscount = discount > 0;

            String getDisplayAmount(PaymentMethod method) {
              switch (method) {
                case PaymentMethod.points:
                  return '✨ ${_totalPoints} 积分';
                case PaymentMethod.cash:
                  if (hasDiscount) {
                    return '¥$_actualPayableCash (原价: ¥$_totalCash)';
                  }
                  return '¥$_totalCash';
                case PaymentMethod.hybrid:
                  final discountedCash = (_totalHybrid['cash'] as int) - _couponDiscount - _redPacketDiscount;
                  final finalCash = discountedCash > 0 ? discountedCash : 0;
                  if (hasDiscount) {
                    return '✨ ${_totalHybrid['points']} 积分 + ¥$finalCash (原价: ¥${_totalHybrid['cash']})';
                  }
                  return '✨ ${_totalHybrid['points']} 积分 + ¥${_totalHybrid['cash']}';
                case PaymentMethod.shoppingCard:
                  return '¥$_actualPayableCash';
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1c2e24),
              title: const Text(
                '选择支付方式',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDiscount)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13ec5b).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF13ec5b).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '优惠抵扣: -¥$discount',
                            style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (_selectedCoupons.isNotEmpty)
                            Text(
                              '优惠券: ${_selectedCoupons.length}张',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          if (_selectedRedPackets.isNotEmpty)
                            Text(
                              '红包: ${_selectedRedPackets.length}个',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  if (isPaymentMethodSupported(PaymentMethod.points))
                    _buildPaymentOption(
                      PaymentMethod.points,
                      '积分支付',
                      getDisplayAmount(PaymentMethod.points),
                      dialogSelectedPayment,
                      (method) {
                        setStateDialog(() {
                          dialogSelectedPayment = method;
                        });
                      },
                    ),
                  if (isPaymentMethodSupported(PaymentMethod.cash))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildPaymentOption(
                        PaymentMethod.cash,
                        '现金支付',
                        getDisplayAmount(PaymentMethod.cash),
                        dialogSelectedPayment,
                        (method) {
                          setStateDialog(() {
                            dialogSelectedPayment = method;
                          });
                        },
                      ),
                    ),
                  if (isPaymentMethodSupported(PaymentMethod.hybrid))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildPaymentOption(
                        PaymentMethod.hybrid,
                        '混合支付',
                        getDisplayAmount(PaymentMethod.hybrid),
                        dialogSelectedPayment,
                        (method) {
                          setStateDialog(() {
                            dialogSelectedPayment = method;
                          });
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    if (_isProcessing) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('操作过于频繁，请稍后再试'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (!isPaymentMethodSupported(dialogSelectedPayment)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('当前选择的支付方式不被所有商品支持'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _selectedPaymentMethod = dialogSelectedPayment;
                    });
                    Navigator.of(context).pop();
                    await _processPayment();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13ec5b),
                    foregroundColor: Colors.black,
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('确认支付'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 构建支付选项
  Widget _buildPaymentOption(
    PaymentMethod method,
    String title,
    String amount,
    PaymentMethod selectedPaymentMethod,
    Function(PaymentMethod) onTap,
  ) {
    final isSelected = selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () {
        onTap(method);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.2) : Colors.black.withOpacity(0.3),
          border: Border.all(
            color: isSelected ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // 自定义单选按钮
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF13ec5b) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.black,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF13ec5b) : Colors.white,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Text(
              amount,
              style: TextStyle(
                color: isSelected ? const Color(0xFF13ec5b) : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() { _isProcessing = true; });
    try {
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';

      final buyerExtension = await _databaseService.getBuyerExtension(userId);
      final defaultAddress = await _databaseService.getDefaultAddress(userId);

      final buyerName = (buyerExtension?['nickname'] ?? '') as String;
      final buyerPhone = (buyerExtension?['phone'] ?? '') as String;
      String deliveryAddress = '';
      if (defaultAddress != null) {
        final province = (defaultAddress['province'] ?? '') as String;
        final city = (defaultAddress['city'] ?? '') as String;
        final district = (defaultAddress['district'] ?? '') as String;
        final detail = (defaultAddress['detail'] ?? '') as String;
        final addressName = (defaultAddress['name'] ?? '') as String;
        final addressPhone = (defaultAddress['phone'] ?? '') as String;
        deliveryAddress = '$province$city$district$detail';
        if (addressName.isNotEmpty) {
          deliveryAddress = '$addressName $addressPhone\n$deliveryAddress';
        }
      }
      
      for (final item in _selectedItems) {
        final product = item.product;
        final currentProductData = await _productDatabaseService.getProductById(product.id!);
        if (currentProductData == null || (currentProductData['stock'] as int) < item.quantity) {
          if (mounted) {
            final currentStock = currentProductData?['stock'] ?? 0;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('商品"${product.name}"库存不足，当前库存${currentStock}件')),
            );
          }
          return;
        }
      }
      
      final totalItems = _selectedItems.length;
      int couponCashDiscountPerItem = 0;
      int redPacketCashDiscountPerItem = 0;
      int couponPointsDiscountPerItem = 0;
      int redPacketPointsDiscountPerItem = 0;
      
      if (totalItems > 0) {
        for (final coupon in _selectedCoupons) {
          final rewardType = coupon['reward_type'] ?? 'cash';
          final couponType = coupon['type'] ?? '';
          final couponAmount = (coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0);
          if (rewardType == 'cash') {
            if (couponType == '满减券' || couponType == '无门槛券' || couponType == '星星券') {
              couponCashDiscountPerItem += couponAmount ~/ totalItems;
            }
          } else if (rewardType == 'points') {
            couponPointsDiscountPerItem += couponAmount ~/ totalItems;
          }
        }
        for (final rp in _selectedRedPackets) {
          final rewardType = rp['reward_type'] ?? 'cash';
          final rpAmount = (rp['amount'] is num ? (rp['amount'] as num).toInt() : 0);
          if (rewardType == 'cash') {
            redPacketCashDiscountPerItem += rpAmount ~/ totalItems;
          } else if (rewardType == 'points') {
            redPacketPointsDiscountPerItem += rpAmount ~/ totalItems;
          }
        }
      }
      
      final usedCouponIds = _selectedCoupons.map((c) => c['id'] as int?).whereType<int>().toList();
      final usedRedPacketIds = _selectedRedPackets.map((r) => r['id'] as int?).whereType<int>().toList();
      
      for (var cartItem in _selectedItems) {
        final product = cartItem.product;
        final int pointsUsed;
        final double cashAmount;
        
        switch (_selectedPaymentMethod) {
          case PaymentMethod.points:
            pointsUsed = product.points * cartItem.quantity - couponPointsDiscountPerItem - redPacketPointsDiscountPerItem;
            cashAmount = 0.0;
            break;
          case PaymentMethod.cash:
            pointsUsed = 0;
            final originalCash = product.price * cartItem.quantity;
            final discountedCash = originalCash - couponCashDiscountPerItem - redPacketCashDiscountPerItem;
            cashAmount = (discountedCash > 0 ? discountedCash : 0) / 100.0;
            break;
          case PaymentMethod.hybrid:
            final hybridPoints = product.hybridPoints > 0 ? product.hybridPoints : product.points ~/ 2;
            final hybridPrice = product.hybridPrice > 0 ? product.hybridPrice : product.price ~/ 2;
            pointsUsed = hybridPoints * cartItem.quantity - couponPointsDiscountPerItem - redPacketPointsDiscountPerItem;
            final originalHybridCash = hybridPrice * cartItem.quantity;
            final discountedHybridCash = originalHybridCash - couponCashDiscountPerItem - redPacketCashDiscountPerItem;
            cashAmount = (discountedHybridCash > 0 ? discountedHybridCash : 0) / 100.0;
            break;
          case PaymentMethod.shoppingCard:
            pointsUsed = 0;
            cashAmount = 0.0;
            break;
        }
        
        final orderData = {
          'id': DateTime.now().millisecondsSinceEpoch.toString() + '_' + product.id.toString(),
          'user_id': userId,
          'product_id': product.id,
          'product_name': product.name,
          'product_image': product.image,
          'points': product.points,
          'product_price': product.price,
          'quantity': cartItem.quantity,
          'status': product.isElectronic ? '待确认' : '待发货',
          'is_electronic': product.isElectronic ? 1 : 0,
          'payment_method': _selectedPaymentMethod.storageValue,
          'points_used': pointsUsed > 0 ? pointsUsed : 0,
          'cash_amount': cashAmount,
          'total_amount': cashAmount,
          'coupon_discount': couponCashDiscountPerItem + couponPointsDiscountPerItem,
          'red_packet_discount': redPacketCashDiscountPerItem + redPacketPointsDiscountPerItem,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'variant': '',
          'fund_status': 'escrow',
          'merchant_id': product.merchantId,
          'buyer_name': buyerName,
          'buyer_phone': buyerPhone,
          'delivery_address': deliveryAddress,
          'buyer_note': '',
        };
        await _databaseService.insertOrder(orderData);
        
        final paymentRecord = PaymentRecord(
          orderId: orderData['id'] as String,
          userId: userId,
          paymentNo: 'PAY${DateTime.now().millisecondsSinceEpoch}${DateTime.now().microsecond}',
          amount: (pointsUsed > 0 ? pointsUsed : 0) + cashAmount.round(),
          pointsUsed: pointsUsed > 0 ? pointsUsed : 0,
          cashAmount: cashAmount.round(),
          paymentMethod: _selectedPaymentMethod.storageValue,
          status: 'success',
          paidAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          merchantId: product.merchantId,
          fundStatus: 'escrow',
        );
        try {
          await _productDatabaseService.insertPaymentRecord(paymentRecord);
        } catch (e) {
          debugPrint('创建支付记录失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('支付记录保存失败: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        if (_selectedPaymentMethod == PaymentMethod.points) {
          await _databaseService.updateUserPoints(
            userId, 
            -(pointsUsed > 0 ? pointsUsed : 0).toDouble(),
            description: '购买商品 - ${product.name}',
            transactionType: 'purchase',
            relatedId: orderData['id'] as String
          );
          ref.read(userPointsProvider.notifier).refresh();
        } else if (_selectedPaymentMethod == PaymentMethod.hybrid) {
          await _databaseService.updateUserPoints(
            userId, 
            -(pointsUsed > 0 ? pointsUsed : 0).toDouble(),
            description: '购买商品 - ${product.name} (混合支付)',
            transactionType: 'purchase',
            relatedId: orderData['id'] as String
          );
          ref.read(userPointsProvider.notifier).refresh();
        }

        final updatedProduct = StarProduct(
          id: product.id,
          name: product.name,
          description: product.description,
          image: product.image,
          mainImages: product.mainImages,
          productCode: product.productCode,
          points: product.points,
          costPrice: product.costPrice,
          stock: product.stock - cartItem.quantity,
          categoryId: product.categoryId,
          brand: product.brand,
          tags: product.tags,
          categoryPath: product.categoryPath,
          isActive: product.isActive,
          isDeleted: product.isDeleted,
          status: product.status,
          shippingTemplateId: product.shippingTemplateId,
          isPreSale: product.isPreSale,
          preSaleEndTime: product.preSaleEndTime,
          releaseTime: product.releaseTime,
          scheduledReleaseTime: product.scheduledReleaseTime,
          sales7Days: product.sales7Days,
          totalSales: product.totalSales + cartItem.quantity,
          visitors: product.visitors,
          conversionRate: product.conversionRate,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
          deletedAt: product.deletedAt,
          skus: product.skus,
          specs: product.specs,
          video: product.video,
          videoCover: product.videoCover,
          videoDescription: product.videoDescription,
          detailImages: product.detailImages,
          detail: product.detail,
          weight: product.weight,
          volume: product.volume,
          originalPrice: product.originalPrice,
          price: product.price,
          memberPrice: product.memberPrice,
          shippingTime: product.shippingTime,
          shippingAddress: product.shippingAddress,
          returnPolicy: product.returnPolicy,
          sortWeight: product.sortWeight,
          isLimitedPurchase: product.isLimitedPurchase,
          limitQuantity: product.limitQuantity,
          internalNote: product.internalNote,
          seoTitle: product.seoTitle,
          seoKeywords: product.seoKeywords,
          supportPointsPayment: product.supportPointsPayment,
          supportCashPayment: product.supportCashPayment,
          supportHybridPayment: product.supportHybridPayment,
        );
        await _productDatabaseService.updateProduct(updatedProduct.id!, updatedProduct.toMap());
        await _productDatabaseService.insertStockRecord(StockRecord(
          productId: product.id!,
          type: 'order',
          quantity: cartItem.quantity,
          stockBefore: product.stock,
          stockAfter: product.stock - cartItem.quantity,
          relatedId: orderData['id'] as String,
          remark: '购物车下单扣减库存',
          operatorId: userId,
          createdAt: DateTime.now(),
        ));
      }
      
      for (var cartItem in _selectedItems) {
        await _databaseService.removeFromCart(cartItem.id);
      }
      
      for (final couponId in usedCouponIds) {
        try {
          await _databaseService.updateUserCouponStatus(couponId, 'used');
        } catch (e) {
          debugPrint('标记优惠券已使用失败: $e');
        }
      }
      for (final redPacketId in usedRedPacketIds) {
        try {
          await _databaseService.updateRedPacketClaimStatus(redPacketId, 'used');
        } catch (e) {
          debugPrint('标记红包已使用失败: $e');
        }
      }
      
      setState(() {
        _selectedItemIds.clear();
        _isAllSelected = false;
        _selectedCoupons.clear();
        _selectedRedPackets.clear();
      });
      
      await _loadCartItems();
      
      if (mounted) {
        final firstProduct = _selectedItems.isNotEmpty ? _selectedItems.first.product : null;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentResultPage(
            isSuccess: true,
            productName: firstProduct?.name,
            isVirtualProduct: firstProduct?.isElectronic ?? false,
          ),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('结算失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  // 结算
  Future<void> _checkout() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('购物车为空'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一个商品'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 显示支付对话框
    await _showPaymentDialog();
  }

  /// 显示优惠券/红包选择对话框
  Future<void> _showCouponSelection() async {
    final applicableCoupons = _availableCoupons.where((c) {
      final condition = c['condition'] as num?;
      if (condition == null || condition == 0) return true;
      return _totalCash >= condition;
    }).toList();
    
    final tempSelectedCoupons = List<Map<String, dynamic>>.from(_selectedCoupons);
    final tempSelectedRedPackets = List<Map<String, dynamic>>.from(_selectedRedPackets);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF1c2e24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '选择优惠券/红包',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: Color(0xFF13ec5b),
                              unselectedLabelColor: Colors.white54,
                              indicatorColor: Color(0xFF13ec5b),
                              tabs: [
                                Tab(text: '优惠券'),
                                Tab(text: '红包'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildCouponList(applicableCoupons, tempSelectedCoupons, (coupon) {
                                    setDialogState(() {
                                      final idx = tempSelectedCoupons.indexWhere((c) => c['id'] == coupon['id']);
                                      if (idx >= 0) {
                                        tempSelectedCoupons.removeAt(idx);
                                      } else {
                                        tempSelectedCoupons.add(coupon);
                                      }
                                    });
                                  }),
                                  _buildRedPacketList(_availableRedPackets, tempSelectedRedPackets, (rp) {
                                    setDialogState(() {
                                      final idx = tempSelectedRedPackets.indexWhere((r) => r['id'] == rp['id']);
                                      if (idx >= 0) {
                                        tempSelectedRedPackets.removeAt(idx);
                                      } else {
                                        tempSelectedRedPackets.add(rp);
                                      }
                                    });
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCoupons = tempSelectedCoupons;
                                  _selectedRedPackets = tempSelectedRedPackets;
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13ec5b),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('确认'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCouponList(List<Map<String, dynamic>> coupons, List<Map<String, dynamic>> selected, Function(Map<String, dynamic>) onToggle) {
    if (coupons.isEmpty) {
      return const Center(
        child: Text('暂无可用优惠券', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        final isSelected = selected.any((c) => c['id'] == coupon['id']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.1) : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(coupon),
                activeColor: const Color(0xFF13ec5b),
                checkColor: Colors.black,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon['name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${coupon['type']} · ${coupon['amount']}',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                    if ((coupon['condition'] as num?) != null && (coupon['condition'] as num) > 0)
                      Text(
                        '满${coupon['condition']}可用',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRedPacketList(List<Map<String, dynamic>> redPackets, List<Map<String, dynamic>> selected, Function(Map<String, dynamic>) onToggle) {
    if (redPackets.isEmpty) {
      return const Center(
        child: Text('暂无可用红包', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: redPackets.length,
      itemBuilder: (context, index) {
        final rp = redPackets[index];
        final isSelected = selected.any((r) => r['id'] == rp['id']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.1) : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(rp),
                activeColor: const Color(0xFF13ec5b),
                checkColor: Colors.black,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rp['name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '红包金额: ¥${rp['amount']}',
                      style: TextStyle(color: const Color(0xFF13ec5b), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.currentTheme;

    return Scaffold(
      backgroundColor: theme.deepSpaceGray,
      appBar: AppBar(
        backgroundColor: theme.deepSpaceGray,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('购物车'),
        centerTitle: true,
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text(
                '清空',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 购物车商品列表
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _cartItems.isEmpty
                    ? _buildEmptyCart()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _buildGroupedItemCount() + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildSelectAllRow();
                          }
                          
                          final groupInfo = _getGroupInfoByIndex(index - 1);
                          if (groupInfo == null) {
                            return const SizedBox.shrink();
                          }
                          
                          if (groupInfo['isHeader'] == true) {
                            return _buildGroupHeader(groupInfo['merchantId'] as int?);
                          }
                          
                          final cartItem = groupInfo['item'] as CartItem;
                          final product = cartItem.product;
                          final quantity = cartItem.quantity;
                          final isValid = _validItemIds[cartItem.id] ?? true;
                          final invalidReason = _invalidReasons[cartItem.id];
                          final itemIndex = groupInfo['itemIndex'] as int;

                          return Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: _buildCartItem(product, quantity, itemIndex, isValid, invalidReason),
                          );
                        },
                      ),
          ),

          // 底部结算栏
          if (_cartItems.isNotEmpty)
            _buildCheckoutBar(),
        ],
      ),
    );
  }

  // 构建加载状态
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '加载购物车中...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建全选行
  Widget _buildSelectAllRow() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Checkbox(
            value: _isAllSelected,
            onChanged: (bool? value) {
              setState(() {
                _isAllSelected = value == true;
                if (_isAllSelected) {
                  // 全选 - 只添加有效商品ID到选中集合
                  final validItems = _cartItems.where((item) => _validItemIds[item.id] == true).toList();
                  _selectedItemIds = validItems.map((item) => item.id).toSet();
                } else {
                  // 取消全选 - 清空选中集合
                  _selectedItemIds.clear();
                }
              });
            },
            activeColor: const Color(0xFF13ec5b),
            checkColor: Colors.black,
          ),
          const SizedBox(width: 8),
          const Text(
            '全选',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 构建空购物车界面
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '购物车是空的',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13ec5b),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('去逛逛'),
          ),
        ],
      ),
    );
  }

  // 构建购物车商品项
  Widget _buildCartItem(StarProduct product, int quantity, int index, bool isValid, String? invalidReason) {
    final cartItem = _cartItems[index];
    final isSelected = _selectedItemIds.contains(cartItem.id);
    
    Widget buildItemContent() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1c2e24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品选择复选框
            Checkbox(
              value: isSelected,
              onChanged: isValid ? (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedItemIds.add(cartItem.id);
                  } else {
                    _selectedItemIds.remove(cartItem.id);
                  }
                  // 更新全选状态
                  _updateSelectAllStatus();
                });
              } : null,
              activeColor: const Color(0xFF13ec5b),
              checkColor: Colors.black,
            ),
            
            const SizedBox(width: 8),
            
            // 商品图片
            GestureDetector(
              onTap: isValid ? () {
                // 跳转到商品详情页
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailPage(product: product),
                  ),
                );
              } : null,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.3),
                ),
                child: Image(
                  image: ImageLoaderService.getImageProvider(product.image),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 商品名称
                  GestureDetector(
                    onTap: isValid ? () {
                      // 跳转到商品详情页
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(product: product),
                        ),
                      );
                    } : null,
                    child: Text(
                      product.name,
                      style: TextStyle(
                        color: isValid ? Colors.white : Colors.white.withOpacity(0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 价格显示 - 与星星商店页保持一致，直接显示原始价格值
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 现金支付价格
                      if (product.supportCashPayment)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '¥${product.price}',
                                style: TextStyle(
                                  color: isValid ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.5),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (product.originalPrice > product.price)
                                Text(
                                  '¥${product.originalPrice}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // 积分支付价格
                      if (product.supportPointsPayment)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '✨${product.points}',
                            style: TextStyle(
                              color: isValid ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.5),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // 混合支付价格 - 与星星商店页保持一致，添加默认值处理
                      if (product.supportHybridPayment)
                        Builder( builder: (context) {
                          // 计算混合支付的价格，添加默认值处理
                          final hybridPrice = product.hybridPrice > 0 ? product.hybridPrice : product.price ~/ 2;
                          final hybridPoints = product.hybridPoints > 0 ? product.hybridPoints : product.points ~/ 2;
                          return Text(
                            '¥$hybridPrice + ✨$hybridPoints',
                            style: TextStyle(
                              color: isValid ? const Color(0xFF13ec5b) : Colors.white.withOpacity(0.5),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 数量控制和删除按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 数量控制
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 减少数量
                            IconButton(
                              onPressed: isValid ? () => _adjustQuantity(index, -1) : null,
                              icon: Icon(
                                Icons.remove,
                                size: 16,
                                color: isValid ? Colors.white : Colors.white.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.all(8),
                            ),

                            // 数量显示
                            Text(
                              '$quantity',
                              style: TextStyle(
                                color: isValid ? Colors.white : Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // 增加数量
                            IconButton(
                              onPressed: isValid ? () => _adjustQuantity(index, 1) : null,
                              icon: Icon(
                                Icons.add,
                                size: 16,
                                color: isValid ? Colors.white : Colors.white.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          ],
                        ),
                      ),

                      // 删除按钮
                      IconButton(
                        onPressed: () => _removeItem(index),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!isValid) {
      return Stack(
        children: [
          Opacity(
            opacity: 0.5,
            child: buildItemContent(),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                invalidReason ?? '已失效',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return buildItemContent();
  }

  // 构建底部结算栏
  Widget _buildCheckoutBar() {
    String getTotalDisplay() {
      switch (_selectedPaymentMethod) {
        case PaymentMethod.points:
          return '✨${_totalPoints}';
        case PaymentMethod.cash:
          return '¥$_actualPayableCash';
        case PaymentMethod.hybrid:
          return '✨${_totalHybrid['points']} + ¥${(_totalHybrid['cash'] as int) - _couponDiscount - _redPacketDiscount > 0 ? (_totalHybrid['cash'] as int) - _couponDiscount - _redPacketDiscount : 0}';
        case PaymentMethod.shoppingCard:
          return '¥$_actualPayableCash';
      }
    }

    String getPaymentMethodTitle() {
      switch (_selectedPaymentMethod) {
        case PaymentMethod.points:
          return '积分支付';
        case PaymentMethod.cash:
          return '现金支付';
        case PaymentMethod.hybrid:
          return '混合支付';
        case PaymentMethod.shoppingCard:
          return '购物卡支付';
      }
    }

    final totalDiscount = _couponDiscount + _redPacketDiscount;
    final hasDiscount = totalDiscount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102216),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 优惠券/红包选择行
          GestureDetector(
            onTap: _showCouponSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer_outlined, size: 18, color: const Color(0xFF13ec5b)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '优惠券: ${_availableCoupons.length}张可用 | 红包: ${_availableRedPackets.length}个可用',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                ],
              ),
            ),
          ),
          // 已选优惠券抵扣显示
          if (_selectedCoupons.isNotEmpty || _selectedRedPackets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedCoupons.isNotEmpty)
                      Text(
                        '已选优惠券抵扣: -¥$_couponDiscount',
                        style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 12),
                      ),
                    if (_selectedRedPackets.isNotEmpty)
                      Text(
                        '已选红包抵扣: -¥$_redPacketDiscount',
                        style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 12),
                      ),
                  ],
                ),
                if (hasDiscount)
                  Text(
                    '原价: ¥$_totalCash',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // 总价显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总价',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '当前支付方式: ${getPaymentMethodTitle()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    getTotalDisplay(),
                    style: const TextStyle(
                      color: Color(0xFF13ec5b),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      '已优惠¥$totalDiscount',
                      style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 12),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 结算按钮
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('立即结算'),
            ),
          ),
        ],
      ),
    );
  }
}