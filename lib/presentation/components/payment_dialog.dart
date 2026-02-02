import 'package:flutter/material.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/pages/shopping_card_page.dart';
import 'package:moment_keep/presentation/pages/coupons_detail_page.dart';

/// 支付方式枚举
enum PaymentMethod {
  points, // 积分支付
  cash, // 现金支付
  hybrid, // 混合支付
}

/// 支付对话框组件
class PaymentDialog extends StatefulWidget {
  /// 商品信息
  final StarProduct product;
  
  /// 选中的SKU（可选）
  final StarProductSku? selectedSku;
  
  /// 选中的规格信息（可选）
  final Map<String, String> selectedSpecs;
  
  /// 构建支付对话框
  const PaymentDialog({
    super.key,
    required this.product,
    this.selectedSku,
    this.selectedSpecs = const {},
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  /// 当前选中的支付方式
  late PaymentMethod _selectedPaymentMethod;
  
  /// 购买数量
  int _quantity = 1;
  
  /// 优惠券、红包和购物卡选择
  List<Map<String, dynamic>> _selectedCoupons = [];
  List<Map<String, dynamic>> _selectedRedPackets = [];
  List<Map<String, dynamic>> _selectedShoppingCards = [];

  @override
  void initState() {
    super.initState();
    
    // 收集商品支持的支付方式
    List<PaymentMethod> availablePaymentMethods = [];
    if (widget.product.supportPointsPayment) {
      availablePaymentMethods.add(PaymentMethod.points);
    }
    if (widget.product.supportCashPayment) {
      availablePaymentMethods.add(PaymentMethod.cash);
    }
    if (widget.product.supportHybridPayment) {
      availablePaymentMethods.add(PaymentMethod.hybrid);
    }
    
    // 默认选择第一种支付方式
    _selectedPaymentMethod = availablePaymentMethods.first;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    
    // 使用选中的SKU价格和库存，如果没有选中则使用商品默认值
    final currentPrice = widget.selectedSku?.price ?? product.price;
    final currentPoints = widget.selectedSku?.points ?? product.points;
    final currentStock = widget.selectedSku?.stock ?? product.stock;
    final currentHybridPrice = widget.selectedSku?.hybridPrice ?? (product.hybridPrice > 0 ? product.hybridPrice : currentPrice ~/ 2);
    final currentHybridPoints = widget.selectedSku?.hybridPoints ?? (product.hybridPoints > 0 ? product.hybridPoints : currentPoints ~/ 2);
    
    // 收集商品支持的支付方式
    List<PaymentMethod> availablePaymentMethods = [];
    if (product.supportPointsPayment) {
      availablePaymentMethods.add(PaymentMethod.points);
    }
    if (product.supportCashPayment) {
      availablePaymentMethods.add(PaymentMethod.cash);
    }
    if (product.supportHybridPayment) {
      availablePaymentMethods.add(PaymentMethod.hybrid);
    }

    return AlertDialog(
      backgroundColor: theme.colorScheme.background,
      title: Text(
        '选择支付方式',
        style: TextStyle(color: theme.colorScheme.onBackground),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8, // 设置最大高度为屏幕高度的80%
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 商品信息
              ListTile(
                leading: Image(
                  image: ImageLoaderService.getImageProvider(product.image),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
                title: Text(
                  product.name,
                  style: TextStyle(color: theme.colorScheme.onBackground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 显示选中的规格
                    if (widget.selectedSpecs.isNotEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _formatSelectedSpecs(widget.selectedSpecs),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    // 数量编辑
                    Row(
                      children: [
                        Text(
                          '数量: ',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_quantity > 1) {
                              setState(() {
                                _quantity--;
                              });
                            }
                          },
                          icon: Icon(Icons.remove, color: theme.colorScheme.onSurface),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                        ),
                        Text(
                          _quantity.toString(),
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_quantity < currentStock) {
                              setState(() {
                                _quantity++;
                              });
                            }
                          },
                          icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '库存: $currentStock',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: theme.colorScheme.outline),
              
              // 优惠券、红包和购物卡选择
              Column(
                children: [
                  // 优惠券选择
                  ListTile(
                    title: Text(
                      '选择优惠券',
                      style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _selectedCoupons.isNotEmpty ? '已选择: ${_selectedCoupons.length}张优惠券' : '未选择优惠券',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                    onTap: () async {
                      // 打开优惠券选择界面
                      final databaseService = DatabaseService();
                      final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                      final selectedCoupons = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CouponsDetailPage(
                            userId: userId,
                            selectMode: true,
                            selectedCoupons: _selectedCoupons,
                          ),
                        ),
                      );
                      if (selectedCoupons != null) {
                        setState(() {
                          if (selectedCoupons is List) {
                            _selectedCoupons = selectedCoupons.cast<Map<String, dynamic>>();
                          } else if (selectedCoupons is Map) {
                            _selectedCoupons = [selectedCoupons.cast<String, dynamic>()];
                          }
                        });
                      }
                    },
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.colorScheme.outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 红包选择
                  GestureDetector(
                    onTap: () async {
                      // 打开红包选择界面
                      final databaseService = DatabaseService();
                      final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                      final selectedRedPackets = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CouponsDetailPage(
                            userId: userId,
                            selectMode: true,
                            selectType: 'red_packet',
                            selectedRedPackets: _selectedRedPackets,
                          ),
                        ),
                      );
                      if (selectedRedPackets != null) {
                        setState(() {
                          if (selectedRedPackets is List) {
                            _selectedRedPackets = selectedRedPackets.cast<Map<String, dynamic>>();
                          } else if (selectedRedPackets is Map) {
                            _selectedRedPackets = [selectedRedPackets.cast<String, dynamic>()];
                          }
                          // 按金额从小到大和快要到期的优先排序
                          _selectedRedPackets.sort((a, b) {
                            // 先按金额排序
                            final amountA = a['amount'] is num ? (a['amount'] as num).toDouble() : 0.0;
                            final amountB = b['amount'] is num ? (b['amount'] as num).toDouble() : 0.0;
                            if (amountA != amountB) {
                              return amountA.compareTo(amountB);
                            }
                            // 金额相同按到期时间排序
                            final validityA = a['validity'] as String? ?? '';
                            final validityB = b['validity'] as String? ?? '';
                            if (validityA == '永久' && validityB != '永久') return -1;
                            if (validityA != '永久' && validityB == '永久') return 1;
                            if (validityA != '永久' && validityB != '永久') {
                              final dateA = DateTime.tryParse(validityA);
                              final dateB = DateTime.tryParse(validityB);
                              if (dateA != null && dateB != null) {
                                return dateA.compareTo(dateB);
                              }
                            }
                            return 0;
                          });
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '选择红包',
                                style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _selectedRedPackets.isNotEmpty ? '已选择: ${_selectedRedPackets.length}个红包' : '未选择红包',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 购物卡选择
                  GestureDetector(
                    onTap: () async {
                      // 打开购物卡选择界面
                      final databaseService = DatabaseService();
                      final userId = await databaseService.getCurrentUserId() ?? 'default_user';
                      final selectedShoppingCards = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShoppingCardPage(
                            userId: userId,
                            selectMode: true,
                            selectedShoppingCards: _selectedShoppingCards,
                          ),
                        ),
                      );
                      if (selectedShoppingCards != null) {
                        setState(() {
                          if (selectedShoppingCards is List) {
                            _selectedShoppingCards = selectedShoppingCards.cast<Map<String, dynamic>>();
                          } else if (selectedShoppingCards is Map) {
                            _selectedShoppingCards = [selectedShoppingCards.cast<String, dynamic>()];
                          }
                          // 按金额从小到大和快要到期的优先排序
                          _selectedShoppingCards.sort((a, b) {
                            // 先按金额排序
                            final amountA = a['amount'] is num ? (a['amount'] as num).toDouble() : 0.0;
                            final amountB = b['amount'] is num ? (b['amount'] as num).toDouble() : 0.0;
                            if (amountA != amountB) {
                              return amountA.compareTo(amountB);
                            }
                            // 金额相同按到期时间排序
                            final validityA = a['validity'] as String? ?? '';
                            final validityB = b['validity'] as String? ?? '';
                            if (validityA == '永久' && validityB != '永久') return -1;
                            if (validityA != '永久' && validityB == '永久') return 1;
                            if (validityA != '永久' && validityB != '永久') {
                              final dateA = DateTime.tryParse(validityA);
                              final dateB = DateTime.tryParse(validityB);
                              if (dateA != null && dateB != null) {
                                return dateA.compareTo(dateB);
                              }
                            }
                            return 0;
                          });
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '选择购物卡',
                                style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _selectedShoppingCards.isNotEmpty ? '已选择: ${_selectedShoppingCards.length}张购物卡' : '未选择购物卡',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 优惠和合计信息
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 计算优惠金额
                      Text(
                        '${_calculateDiscountInfo(currentPrice, currentPoints, _quantity, _selectedPaymentMethod, _selectedCoupons, _selectedRedPackets, _selectedShoppingCards, hybridPrice: currentHybridPrice, hybridPoints: currentHybridPoints)}',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      // 计算合计金额
                      Text(
                        '${_calculateTotalInfo(currentPrice, currentPoints, _quantity, _selectedPaymentMethod, _selectedCoupons, _selectedRedPackets, _selectedShoppingCards, hybridPrice: currentHybridPrice, hybridPoints: currentHybridPoints)}',
                        style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 支付方式选择
              Text(
                '请选择支付方式',
                style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // 支付方式列表
              ...availablePaymentMethods.map((method) {
                String methodText;
                String priceText;
                Color color = theme.colorScheme.primary;

                // 计算支付金额
                if (method == PaymentMethod.points) {
                  methodText = '积分支付';
                  int totalPoints = currentPoints * _quantity;
                  // 应用优惠券
                  for (final coupon in _selectedCoupons) {
                    // 根据优惠券类型计算折扣金额
                    final couponType = coupon['type'] as String? ?? '';
                    
                    if (couponType == '折扣券') {
                      // 折扣券：使用 discount 字段计算折扣金额
                      dynamic discountValue;
                      if (coupon.containsKey('discount')) {
                        discountValue = coupon['discount'];
                      }
                      
                      if (discountValue is num) {
                        // 计算折扣金额：原价 * (1 - 折扣率)
                        final originalAmount = currentPoints * _quantity;
                        final discountAmount = originalAmount * (1 - discountValue.toDouble());
                        // 积分支付时，对折扣金额进行上取整
                        final couponAmount = discountAmount.ceil();
                        totalPoints -= couponAmount;
                      }
                    } else {
                      // 满减券：使用 amount 字段作为折扣金额
                      final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0;
                      totalPoints -= couponAmount;
                    }
                    if (totalPoints < 0) totalPoints = 0;
                  }
                  // 应用红包
                  for (final redPacket in _selectedRedPackets) {
                    // 积分支付时，只考虑星星红包和积分红包
                    final redPacketType = redPacket['type'] as String? ?? '';
                    if (redPacketType == '星星红包' || redPacketType == '积分红包') {
                      final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0;
                      totalPoints -= redPacketAmount;
                      if (totalPoints < 0) totalPoints = 0;
                    }
                  }
                  priceText = '✨$totalPoints';
                } else if (method == PaymentMethod.cash) {
                  methodText = '现金支付';
                  double totalCash = currentPrice.toDouble() * _quantity;
                  // 应用优惠券
                  for (final coupon in _selectedCoupons) {
                    final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
                    totalCash -= couponAmount;
                    if (totalCash < 0) totalCash = 0;
                  }
                  // 应用红包
                  for (final redPacket in _selectedRedPackets) {
                    // 现金支付时，只考虑金钱红包
                    final redPacketType = redPacket['type'] as String? ?? '';
                    if (redPacketType != '星星红包' && redPacketType != '积分红包') {
                      final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toDouble() : 0.0;
                      totalCash -= redPacketAmount;
                      if (totalCash < 0) totalCash = 0;
                    }
                  }
                  // 应用购物卡
                  if (_selectedShoppingCards.isNotEmpty) {
                    // 现金支付时，只考虑金钱购物卡
                    bool hasValidShoppingCard = false;
                    for (final card in _selectedShoppingCards) {
                      final cardType = card['type'] as String? ?? '';
                      if (cardType != '星星购物卡' && cardType != '积分购物卡') {
                        hasValidShoppingCard = true;
                        break;
                      }
                    }
                    if (hasValidShoppingCard) {
                      totalCash = 0;
                    }
                  }
                  priceText = '¥${totalCash.toStringAsFixed(2)}';
                } else {
                  methodText = '混合支付';
                  double cashTotal = currentHybridPrice.toDouble() * _quantity;
                  int pointsTotal = currentHybridPoints * _quantity;
                  // 应用优惠券到现金部分
                  for (final coupon in _selectedCoupons) {
                    final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
                    cashTotal -= couponAmount;
                    if (cashTotal < 0) cashTotal = 0;
                  }
                  // 应用红包
                  for (final redPacket in _selectedRedPackets) {
                    final redPacketType = redPacket['type'] as String? ?? '';
                    if (redPacketType == '星星红包' || redPacketType == '积分红包') {
                      // 星星红包和积分红包抵扣积分部分
                      final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0;
                      pointsTotal -= redPacketAmount;
                      if (pointsTotal < 0) pointsTotal = 0;
                    } else {
                      // 金钱红包抵扣现金部分
                      final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toDouble() : 0.0;
                      cashTotal -= redPacketAmount;
                      if (cashTotal < 0) cashTotal = 0;
                    }
                  }
                  // 应用购物卡
                  if (_selectedShoppingCards.isNotEmpty) {
                    bool hasCashShoppingCard = false;
                    bool hasPointsShoppingCard = false;
                    for (final card in _selectedShoppingCards) {
                      final cardType = card['type'] as String? ?? '';
                      if (cardType == '星星购物卡' || cardType == '积分购物卡') {
                        hasPointsShoppingCard = true;
                      } else {
                        hasCashShoppingCard = true;
                      }
                    }
                    if (hasCashShoppingCard) {
                      cashTotal = 0;
                    }
                    if (hasPointsShoppingCard) {
                      pointsTotal = 0;
                    }
                  }
                  priceText = '¥${cashTotal.toStringAsFixed(2)} + ✨$pointsTotal';
                }

                return RadioListTile<PaymentMethod>(
                  value: method,
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    }
                  },
                  title: Text(
                    methodText,
                    style: TextStyle(color: theme.colorScheme.onBackground),
                  ),
                  subtitle: Text(
                    priceText,
                    style: TextStyle(color: color),
                  ),
                  activeColor: theme.colorScheme.primary,
                  tileColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.colorScheme.outline),
                  ),
                );
              }),
            ],
          ),
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
            Navigator.pop(context);
            // 处理支付逻辑
            await _handlePayment(
              widget.product,
              _selectedPaymentMethod, 
              _quantity, 
              selectedCoupons: _selectedCoupons, 
              selectedRedPackets: _selectedRedPackets,
              selectedShoppingCards: _selectedShoppingCards,
              selectedSku: widget.selectedSku,
              selectedSpecs: widget.selectedSpecs,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: Text('确认支付'),
        ),
      ],
    );
  }

  /// 格式化选中的规格为可读字符串
  String _formatSelectedSpecs(Map<String, String> selectedSpecs) {
    return selectedSpecs.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('; ');
  }

  /// 计算优惠信息
  String _calculateDiscountInfo(int price, int points, int quantity, PaymentMethod paymentMethod, List<Map<String, dynamic>> selectedCoupons, List<Map<String, dynamic>> redPackets, List<Map<String, dynamic>> shoppingCards, {int hybridPrice = 50, int hybridPoints = 1}) {
    double discount = 0.0;
    String unit = paymentMethod == PaymentMethod.points ? '✨' : '¥';

    // 计算优惠券折扣
    for (final coupon in selectedCoupons) {
      // 调试：打印优惠券数据结构
      print('优惠券数据: $coupon');
      
      double couponAmount = 0.0;
      
      // 根据优惠券类型计算折扣金额
      final couponType = coupon['type'] as String? ?? '';
      
      if (couponType == '折扣券') {
        // 折扣券：使用 discount 字段计算折扣金额
        dynamic discountValue;
        if (coupon.containsKey('discount')) {
          discountValue = coupon['discount'];
        }
        
        if (discountValue is num) {
          // 计算折扣金额：原价 * (1 - 折扣率)
          double originalAmount;
          if (paymentMethod == PaymentMethod.points) {
            originalAmount = points.toDouble() * quantity;
          } else if (paymentMethod == PaymentMethod.hybrid) {
            originalAmount = hybridPrice.toDouble();
          } else {
            originalAmount = price.toDouble() * quantity;
          }
          couponAmount = originalAmount * (1 - discountValue.toDouble());
        }
      } else {
        // 满减券：使用 amount 字段作为折扣金额
        // 尝试从不同的键获取金额
        dynamic amountValue;
        if (coupon.containsKey('amount')) {
          amountValue = coupon['amount'];
        } else if (coupon.containsKey('value')) {
          amountValue = coupon['value'];
        } else if (coupon.containsKey('points')) {
          amountValue = coupon['points'];
        }
        
        if (amountValue is num) {
          couponAmount = amountValue.toDouble();
        } else if (amountValue is String) {
          try {
            couponAmount = double.parse(amountValue);
          } catch (e) {
            couponAmount = 0.0;
          }
        }
      }
      
      print('优惠券金额: $couponAmount');
      discount += couponAmount;
    }

    // 确保折扣不为负数
    if (discount < 0) discount = 0;

    // 积分支付时，对折扣金额进行上取整
    if (paymentMethod == PaymentMethod.points) {
      discount = discount.ceilToDouble();
    }

    print('总折扣: $discount');
    return '优惠：$unit${discount.toStringAsFixed(paymentMethod == PaymentMethod.points ? 0 : 2)}';
  }

  /// 计算合计信息
  String _calculateTotalInfo(int price, int points, int quantity, PaymentMethod paymentMethod, List<Map<String, dynamic>> selectedCoupons, List<Map<String, dynamic>> redPackets, List<Map<String, dynamic>> shoppingCards, {int hybridPrice = 50, int hybridPoints = 1}) {
    // 积分支付的计算
    if (paymentMethod == PaymentMethod.points) {
      // 初始总金额
      int total = points * quantity;
      
      // 应用优惠券折扣
      for (final coupon in selectedCoupons) {
        int couponAmount = 0;
        
        // 根据优惠券类型计算折扣金额
        final couponType = coupon['type'] as String? ?? '';
        
        if (couponType == '折扣券') {
          // 折扣券：使用 discount 字段计算折扣金额
          dynamic discountValue;
          if (coupon.containsKey('discount')) {
            discountValue = coupon['discount'];
          }
          
          if (discountValue is num) {
            // 计算折扣金额：原价 * (1 - 折扣率)
            final originalAmount = points * quantity;
            final discountAmount = originalAmount * (1 - discountValue.toDouble());
            // 积分支付时，对折扣金额进行上取整
            couponAmount = discountAmount.ceil();
          }
        } else {
          // 满减券：使用 amount 字段作为折扣金额
          dynamic amountValue;
          if (coupon.containsKey('amount')) {
            amountValue = coupon['amount'];
          } else if (coupon.containsKey('value')) {
            amountValue = coupon['value'];
          } else if (coupon.containsKey('points')) {
            amountValue = coupon['points'];
          }
          
          if (amountValue is num) {
            couponAmount = amountValue.toInt();
          } else if (amountValue is String) {
            try {
              couponAmount = int.parse(amountValue);
            } catch (e) {
              couponAmount = 0;
            }
          }
        }
        
        print('优惠券金额 (积分支付): $couponAmount');
        total -= couponAmount;
        // 确保金额不为负数
        if (total < 0) total = 0;
      }
      
      // 合计金额不应用红包折扣，只在支付方式选项中显示
      
      return '合计：✨$total';
    }
    
    // 现金支付的计算
    else if (paymentMethod == PaymentMethod.cash) {
      // 初始总金额
      double total = price * quantity.toDouble();
      
      // 应用优惠券折扣
      for (final coupon in selectedCoupons) {
        final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
        total -= couponAmount;
        // 确保金额不为负数
        if (total < 0) total = 0;
      }
      
      // 合计金额不应用红包折扣，只在支付方式选项中显示
      
      // 应用购物卡折扣
      if (shoppingCards.isNotEmpty) {
        bool hasValidShoppingCard = false;
        for (final card in shoppingCards) {
          final cardType = card['type'] as String? ?? '';
          if (cardType != '星星购物卡' && cardType != '积分购物卡') {
            hasValidShoppingCard = true;
            break;
          }
        }
        if (hasValidShoppingCard) {
          total = 0;
        }
      }
      
      return '合计：¥${total.toStringAsFixed(2)}';
    }
    
    // 混合支付的计算
    else {
      // 初始总金额 - 使用混合支付的价格
      double cashTotal = hybridPrice.toDouble(); // 混合支付价格
      int pointsTotal = hybridPoints; // 混合支付积分
      
      // 应用优惠券折扣到现金部分
      for (final coupon in selectedCoupons) {
        final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toDouble() : 0.0;
        cashTotal -= couponAmount;
        // 确保金额不为负数
        if (cashTotal < 0) cashTotal = 0;
      }
      
      // 合计金额不应用红包折扣，只在支付方式选项中显示
      
      // 应用购物卡折扣
      if (shoppingCards.isNotEmpty) {
        bool hasCashShoppingCard = false;
        bool hasPointsShoppingCard = false;
        for (final card in shoppingCards) {
          final cardType = card['type'] as String? ?? '';
          if (cardType == '星星购物卡' || cardType == '积分购物卡') {
            hasPointsShoppingCard = true;
          } else {
            hasCashShoppingCard = true;
          }
        }
        if (hasCashShoppingCard) {
          cashTotal = 0;
        }
        if (hasPointsShoppingCard) {
          pointsTotal = 0;
        }
      }
      
      return '合计：¥${cashTotal.toStringAsFixed(2)} + ✨$pointsTotal';
    }
  }

  /// 处理支付逻辑
  Future<void> _handlePayment(
      StarProduct product, PaymentMethod paymentMethod, int quantity, 
      {List<Map<String, dynamic>> selectedCoupons = const [], 
       List<Map<String, dynamic>> selectedRedPackets = const [],
       List<Map<String, dynamic>> selectedShoppingCards = const [],
       StarProductSku? selectedSku,
       Map<String, String>? selectedSpecs}) async {
    try {
      // 检查商品库存是否足够
      final currentStock = selectedSku?.stock ?? product.stock;
      if (currentStock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品库存不足，无法兑换'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 获取当前用户ID
      final databaseService = DatabaseService();
      final productDatabaseService = ProductDatabaseService();
      final userId = await databaseService.getCurrentUserId() ?? 'default_user';

      // 保存原始金额用于订单记录
      double originalPoints = 0.0;
      int originalCash = 0;

      // 根据支付方式计算支付金额和积分
      double points = 0.0;
      int cash = 0;

      // 使用选中的SKU价格和库存，如果没有选中则使用商品默认值
      final currentPrice = selectedSku?.price ?? product.price;
      final currentPoints = selectedSku?.points ?? product.points;
      final currentHybridPrice = selectedSku?.hybridPrice ?? (product.hybridPrice > 0 ? product.hybridPrice : currentPrice ~/ 2);
      final currentHybridPoints = selectedSku?.hybridPoints ?? (product.hybridPoints > 0 ? product.hybridPoints : currentPoints ~/ 2);

      switch (paymentMethod) {
        case PaymentMethod.points:
          points = (currentPoints * quantity).toDouble();
          cash = 0;
          break;
        case PaymentMethod.cash:
          points = 0.0;
          cash = currentPrice * quantity;
          break;
        case PaymentMethod.hybrid:
          points = (currentHybridPoints * quantity).toDouble();
          cash = currentHybridPrice * quantity;
          break;
      }

      // 保存原始金额用于订单记录
      originalPoints = points;
      originalCash = cash;

      // 应用优惠券
      int couponDiscount = 0;
      if (selectedCoupons.isNotEmpty) {
        for (final coupon in selectedCoupons) {
          // 检查优惠券有效期
          final validity = coupon['validity'] as String? ?? '';
          if (validity != '永久') {
            final validityDate = DateTime.tryParse(validity);
            if (validityDate == null || validityDate.isBefore(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('优惠券已过期，无法使用'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }

          // 检查优惠券使用条件
          final couponCondition = coupon['condition'] is num ? (coupon['condition'] as num).toInt() : 0;
          // 对于积分支付，将积分转换为现金价值进行条件检查
          final totalValue = cash + (points / 100); // 假设100积分=1元
          if (totalValue < couponCondition) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('订单金额未达到优惠券使用条件'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // 应用优惠券折扣
          if (coupon['type'] == '满减券' || coupon['type'] == '优惠券') {
            final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0;
            couponDiscount += couponAmount;
            if (cash > 0) {
              // 优先抵扣现金
              cash -= couponAmount;
              if (cash < 0) cash = 0;
            } else {
              // 无现金时抵扣积分
              // 直接使用优惠券金额作为积分折扣，因为优惠券金额已经是以积分形式表示的
              points -= couponAmount.toDouble();
              if (points < 0) points = 0;
            }
          } else if (coupon['type'] == '折扣券') {
            final discount = coupon['discount'] is num ? (coupon['discount'] as num) : 1.0;
            // 对现金和积分都应用折扣
            cash = (cash * discount).round();
            // 对积分直接应用折扣，保留小数
            points = points * discount;
            // 计算折扣金额
            couponDiscount += (originalCash + (originalPoints ~/ 100)) - (cash + (points ~/ 100));
          } else if (coupon['type'] == '无门槛券') {
            final couponAmount = coupon['amount'] is num ? (coupon['amount'] as num).toInt() : 0;
            couponDiscount += couponAmount;
            if (cash > 0) {
              // 优先抵扣现金
              cash -= couponAmount;
              if (cash < 0) cash = 0;
            } else {
              // 无现金时抵扣积分
              // 直接使用优惠券金额作为积分折扣，因为优惠券金额已经是以积分形式表示的
              points -= couponAmount.toDouble();
              if (points < 0) points = 0;
            }
          }
        }
      }

      // 应用红包或购物卡
      int redPacketDiscount = 0;
      int shoppingCardDiscount = 0;

      // 开始事务
      // 1. 生成18位订单ID：时间戳+业务流水+用户基因段
      final orderId = _generateOrderId();

      // 应用红包
      if (selectedRedPackets.isNotEmpty) {
        for (final redPacket in selectedRedPackets) {
          // 检查红包有效期
          final validity = redPacket['validity'] as String? ?? '';
          if (validity != '永久') {
            final validityDate = DateTime.tryParse(validity);
            if (validityDate == null || validityDate.isBefore(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('红包已过期，无法使用'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }

          // 应用红包金额
          final redPacketAmount = redPacket['amount'] is num ? (redPacket['amount'] as num).toInt() : 0;

          // 检查红包类型
          final redPacketType = redPacket['type'];
          if (redPacketType == '积分红包' || redPacketType == '星星红包') {
            // 积分红包或星星红包直接抵扣积分
            if (points > 0) {
              // 计算实际需要的红包金额（使用应用优惠券后的points值）
              final actualDiscount = points;
              redPacketDiscount += actualDiscount.toInt();

              // 如果需要支付积分，使用红包抵扣
              if (redPacketAmount >= actualDiscount) {
                // 红包金额足够支付全部积分
                points = 0.0;
                // 更新红包余额
                final remainingAmount = redPacketAmount - actualDiscount.toInt();
                final redPacketId = redPacket['id'];
                if (redPacketId != null) {
                  if (remainingAmount > 0) {
                    // 红包还有剩余，只更新余额
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'amount': remainingAmount,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  } else {
                    // 红包金额刚好用完，设置为已使用
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'status': '已使用',
                          'used_at': DateTime.now().millisecondsSinceEpoch,
                          'used_order_id': orderId,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  }
                }
              } else {
                // 红包金额不够，部分抵扣
                points -= redPacketAmount;
                redPacketDiscount += redPacketAmount;
                // 红包金额全部用完，设置为已使用
                final redPacketId = redPacket['id'];
                if (redPacketId != null) {
                  await databaseService.database.then((db) async {
                    await db.update(
                      'red_packets',
                      {
                        'status': '已使用',
                        'used_at': DateTime.now().millisecondsSinceEpoch,
                        'used_order_id': orderId,
                        'updated_at': DateTime.now().millisecondsSinceEpoch,
                      },
                      where: 'id = ?',
                      whereArgs: [redPacketId],
                    );
                  });
                }
              }
            }
          } else {
            // 现金红包
            if (cash > 0) {
              // 计算实际需要的红包金额（使用应用优惠券后的cash值）
              final actualDiscount = cash;
              redPacketDiscount += actualDiscount;

              // 使用红包抵扣现金
              if (redPacketAmount >= actualDiscount) {
                // 红包金额足够支付全部现金
                cash = 0;
                // 更新红包余额
                final remainingAmount = redPacketAmount - actualDiscount;
                final redPacketId = redPacket['id'];
                if (redPacketId != null) {
                  if (remainingAmount > 0) {
                    // 红包还有剩余，只更新余额
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'amount': remainingAmount,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  } else {
                    // 红包金额刚好用完，设置为已使用
                    await databaseService.database.then((db) async {
                      await db.update(
                        'red_packets',
                        {
                          'status': '已使用',
                          'used_at': DateTime.now().millisecondsSinceEpoch,
                          'used_order_id': orderId,
                          'updated_at': DateTime.now().millisecondsSinceEpoch,
                        },
                        where: 'id = ?',
                        whereArgs: [redPacketId],
                      );
                    });
                  }
                }
              } else {
                // 红包金额不够，部分抵扣
                cash -= redPacketAmount;
                redPacketDiscount += redPacketAmount;
                // 红包金额全部用完，设置为已使用
                final redPacketId = redPacket['id'];
                if (redPacketId != null) {
                  await databaseService.database.then((db) async {
                    await db.update(
                      'red_packets',
                      {
                        'status': '已使用',
                        'used_at': DateTime.now().millisecondsSinceEpoch,
                        'used_order_id': orderId,
                        'updated_at': DateTime.now().millisecondsSinceEpoch,
                      },
                      where: 'id = ?',
                      whereArgs: [redPacketId],
                    );
                  });
                }
              }
            }
          }
        }
      }

      // 应用购物卡
      if (selectedShoppingCards.isNotEmpty) {
        for (final shoppingCard in selectedShoppingCards) {
          // 检查购物卡有效期
          final validity = shoppingCard['validity'] as String? ?? '';
          if (validity != '永久') {
            final validityDate = DateTime.tryParse(validity);
            if (validityDate == null || validityDate.isBefore(DateTime.now())) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡已过期，无法使用'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }

          // 检查购物卡余额
          final shoppingCardAmount = shoppingCard['amount'] is num ? (shoppingCard['amount'] as num).toInt() : 0;
          if (cash > 0) {
            if (shoppingCardAmount < cash) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡余额不足，无法支付'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // 使用购物卡支付
            shoppingCardDiscount += cash;
            // 计算购物卡剩余余额
            final remainingAmount = shoppingCardAmount - cash;
            // 更新购物卡余额
            shoppingCard['amount'] = remainingAmount;
            cash = 0;
          } else if (points > 0) {
            // 积分支付时，将积分转换为现金价值
            final pointsValue = points.toInt();
            if (shoppingCardAmount < pointsValue) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('购物卡余额不足，无法支付'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // 使用购物卡支付
            shoppingCardDiscount += pointsValue;
            // 计算购物卡剩余余额
            final remainingAmount = shoppingCardAmount - pointsValue;
            // 更新购物卡余额
            shoppingCard['amount'] = remainingAmount;
            points = 0.0;
          }

          // 更新购物卡状态
          final shoppingCardId = shoppingCard['id'] as String;
          final remainingAmount = shoppingCard['amount'] is num ? (shoppingCard['amount'] as num).toInt() : 0;
          await databaseService.database.then((db) async {
            await db.update(
              'shopping_cards',
              {
                'amount': remainingAmount,
                'status': remainingAmount > 0 ? '可用' : '已使用',
                'used_at': DateTime.now().millisecondsSinceEpoch,
                'used_order_id': orderId,
                'used_date': DateTime.now().toString().substring(0, 10),
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [shoppingCardId],
            );
          });
        }
      }

      // 显示确认窗口
      final confirmExchange = await _showExchangeConfirmationDialog(
          product, quantity, paymentMethod, selectedSku);

      if (confirmExchange == true) {
        // 2. 保存订单记录
        await databaseService.database.then((db) async {
          await db.insert('orders', {
            'order_id': orderId,
            'user_id': userId,
            'product_id': product.id,
            'product_name': product.name,
            'product_image': product.image,
            'sku_id': selectedSku?.id ?? '',
            'specs': selectedSpecs != null ? selectedSpecs.toString() : '',
            'quantity': quantity,
            'original_price': originalCash,
            'original_points': originalPoints,
            'actual_price': cash,
            'actual_points': points,
            'coupon_discount': couponDiscount,
            'red_packet_discount': redPacketDiscount,
            'shopping_card_discount': shoppingCardDiscount,
            'payment_method': paymentMethod.toString().split('.').last,
            'status': '已完成',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'created_date': DateTime.now().toString().substring(0, 10),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        });

        // 3. 更新商品库存
        final newStock = currentStock - quantity;
        if (selectedSku != null && selectedSku.id != null) {
          await productDatabaseService.updateSkuStock(selectedSku.id!, newStock);
        } else if (product.id != null) {
          await productDatabaseService.updateProductStock(product.id!, newStock);
        }

        // 4. 扣除用户积分或余额
        if (paymentMethod == PaymentMethod.points) {
          // 扣除积分
          await databaseService.database.then((db) async {
            final user = await db.query('users', where: 'id = ?', whereArgs: [userId]).then((result) => result.isNotEmpty ? result.first : null);
            if (user != null) {
              final currentPoints = user['points'] is int ? user['points'] as int : 0;
              final newPoints = currentPoints - points.toInt();
              await db.update('users', {'points': newPoints, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [userId]);
            }
          });
        } else if (paymentMethod == PaymentMethod.cash) {
          // 扣除余额
          await databaseService.database.then((db) async {
            final user = await db.query('users', where: 'id = ?', whereArgs: [userId]).then((result) => result.isNotEmpty ? result.first : null);
            if (user != null) {
              final currentBalance = user['balance'] is double ? user['balance'] as double : 0.0;
              final newBalance = currentBalance - cash;
              await db.update('users', {'balance': newBalance, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [userId]);
            }
          });
        } else {
          // 混合支付，同时扣除余额和积分
          await databaseService.database.then((db) async {
            final user = await db.query('users', where: 'id = ?', whereArgs: [userId]).then((result) => result.isNotEmpty ? result.first : null);
            if (user != null) {
              final currentBalance = user['balance'] is double ? user['balance'] as double : 0.0;
              final currentPoints = user['points'] is int ? user['points'] as int : 0;
              final newBalance = currentBalance - cash;
              final newPoints = currentPoints - points.toInt();
              await db.update('users', {
                'balance': newBalance,
                'points': newPoints,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              }, where: 'id = ?', whereArgs: [userId]);
            }
          });
        }

        // 5. 记录交易明细
        await databaseService.database.then((db) async {
          await db.insert('transactions', {
            'transaction_id': _generateTransactionId(),
            'user_id': userId,
            'order_id': orderId,
            'type': '支出',
            'amount': cash,
            'points': points.toInt(),
            'description': '购买商品：${product.name}',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'created_date': DateTime.now().toString().substring(0, 10),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        });

        // 6. 发送通知
        await databaseService.database.then((db) async {
          await db.insert('notifications', {
            'notification_id': _generateNotificationId(),
            'user_id': userId,
            'title': '购买成功',
            'content': '您已成功购买 ${product.name} x $quantity',
            'type': 'success',
            'read': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'created_date': DateTime.now().toString().substring(0, 10),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        });

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('购买成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('购买失败，请重试：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 生成订单ID
  String _generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
    return 'ORD$timestamp$random';
  }

  /// 生成交易ID
  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
    return 'TRX$timestamp$random';
  }

  /// 生成通知ID
  String _generateNotificationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
    return 'NOT$timestamp$random';
  }

  /// 显示兑换确认对话框
  Future<bool?> _showExchangeConfirmationDialog(
      StarProduct product, int quantity, PaymentMethod paymentMethod, StarProductSku? selectedSku) async {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text(
            '确认兑换',
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '商品：${product.name}',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              Text(
                '数量：$quantity',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              Text(
                '支付方式：${paymentMethod.toString().split('.').last}',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              Text(
                '确定要兑换这个商品吗？',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }
}

/// 显示支付对话框的便捷函数
Future<void> showPaymentDialog({
  required BuildContext context,
  required StarProduct product,
  StarProductSku? selectedSku,
  Map<String, String> selectedSpecs = const {},
}) async {
  await showDialog(
    context: context,
    builder: (context) {
      return PaymentDialog(
        product: product,
        selectedSku: selectedSku,
        selectedSpecs: selectedSpecs,
      );
    },
  );
}
