import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/cart_database_service.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';

// 支付方式枚举
enum PaymentMethod {
  points, // 积分支付
  cash, // 现金支付
  hybrid, // 混合支付
}

class ShoppingCartPage extends StatefulWidget {
  const ShoppingCartPage({super.key});

  @override
  State<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  // 真实购物车数据
  List<CartItem> _cartItems = [];
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;

  // 当前选择的支付方式
  PaymentMethod _selectedPaymentMethod = PaymentMethod.points;
  
  // 商品选择状态管理 - 存储选中的商品ID
  Set<int> _selectedItemIds = {};
  // 全选状态
  bool _isAllSelected = false;

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
      setState(() {
        _cartItems = items;
        _isLoading = false;
      });
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

  // 获取选中的购物车商品
  List<CartItem> get _selectedItems {
    return _cartItems.where((item) => _selectedItemIds.contains(item.id)).toList();
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
    // 检查是否所有选中商品都支持当前支付方式
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
        }
      }
      return true;
    }

    // 确保默认选中的支付方式是被所有商品支持的
    if (!isPaymentMethodSupported(_selectedPaymentMethod)) {
      // 优先选择现金支付，如果支持的话
      if (isPaymentMethodSupported(PaymentMethod.cash)) {
        _selectedPaymentMethod = PaymentMethod.cash;
      } 
      // 否则选择积分支付，如果支持的话
      else if (isPaymentMethodSupported(PaymentMethod.points)) {
        _selectedPaymentMethod = PaymentMethod.points;
      } 
      // 最后选择混合支付
      else if (isPaymentMethodSupported(PaymentMethod.hybrid)) {
        _selectedPaymentMethod = PaymentMethod.hybrid;
      }
    }

    // 创建一个变量来保存对话框内的当前选中支付方式
    PaymentMethod dialogSelectedPayment = _selectedPaymentMethod;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // 使用StatefulBuilder来管理对话框内部的状态
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1c2e24),
              title: const Text(
                '选择支付方式',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 根据商家设置显示可用的支付方式
                  // 积分支付选项
                  if (isPaymentMethodSupported(PaymentMethod.points))
                    _buildPaymentOption(
                      PaymentMethod.points,
                      '积分支付',
                      '✨ ${_totalPoints} 积分',
                      dialogSelectedPayment,
                      (method) {
                        setStateDialog(() {
                          dialogSelectedPayment = method;
                        });
                      },
                    ),
                  // 现金支付选项
                  if (isPaymentMethodSupported(PaymentMethod.cash))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildPaymentOption(
                        PaymentMethod.cash,
                        '现金支付',
                        '¥$_totalCash',
                        dialogSelectedPayment,
                        (method) {
                          setStateDialog(() {
                            dialogSelectedPayment = method;
                          });
                        },
                      ),
                    ),
                  // 混合支付选项
                  if (isPaymentMethodSupported(PaymentMethod.hybrid))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildPaymentOption(
                        PaymentMethod.hybrid,
                        '混合支付',
                        '✨ ${_totalHybrid['points']} 积分 + ¥${_totalHybrid['cash']}',
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
                  onPressed: () async {
                    // 确保选择的支付方式是支持的
                    if (!isPaymentMethodSupported(dialogSelectedPayment)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('当前选择的支付方式不被所有商品支持'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    // 更新页面状态
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
                  child: const Text('确认支付'),
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

  // 处理支付
  Future<void> _processPayment() async {
    try {
      // 1. 创建订单
      final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      
      // 2. 为每个选中商品创建一个订单
      for (var cartItem in _selectedItems) {
        final product = cartItem.product;
        // 根据支付方式计算订单金额
        final int pointsUsed;
        final double cashAmount;
        
        switch (_selectedPaymentMethod) {
          case PaymentMethod.points:
            pointsUsed = product.points * cartItem.quantity;
            cashAmount = 0.0;
            break;
          case PaymentMethod.cash:
            pointsUsed = 0;
            cashAmount = (product.price / 100.0) * cartItem.quantity;
            break;
          case PaymentMethod.hybrid:
            // 与星星商店页保持一致，添加默认值处理
            final hybridPoints = product.hybridPoints > 0 ? product.hybridPoints : product.points ~/ 2;
            final hybridPrice = product.hybridPrice > 0 ? product.hybridPrice : product.price ~/ 2;
            pointsUsed = hybridPoints * cartItem.quantity;
            cashAmount = (hybridPrice / 100.0) * cartItem.quantity;
            break;
        }
        
        // 创建订单，支付完成后状态为待发货
        final orderData = {
          'id': DateTime.now().millisecondsSinceEpoch.toString() + '_' + product.id.toString(),
          'user_id': userId,
          'product_id': product.id,
          'product_name': product.name,
          'product_image': product.image,
          'points': product.points,
          'product_price': product.price, // 使用正确的字段名product_price
          'quantity': cartItem.quantity,
          'status': '待发货', // 支付完成后状态为待发货，需要经过商家发货流程
          'is_electronic': 0,
          'payment_method': _selectedPaymentMethod.toString().split('.').last,
          'points_used': pointsUsed,
          'cash_amount': cashAmount,
          'total_amount': pointsUsed > 0 ? pointsUsed.toDouble() : cashAmount,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'variant': '', // 添加空的规格字段，避免显示默认值
        };
        final orderId = await _databaseService.insertOrder(orderData);
        
        // 根据支付方式处理支付
        // 1. 积分支付 - 扣除用户积分
        if (_selectedPaymentMethod == PaymentMethod.points) {
          await _databaseService.updateUserPoints(
            userId, 
            -pointsUsed.toDouble(),
            description: '购买商品 - ${product.name}',
            transactionType: 'purchase',
            relatedId: orderData['id'] as String
          );
        }
        // 2. 混合支付 - 扣除用户积分
        else if (_selectedPaymentMethod == PaymentMethod.hybrid) {
          await _databaseService.updateUserPoints(
            userId, 
            -pointsUsed.toDouble(),
            description: '购买商品 - ${product.name} (混合支付)',
            transactionType: 'purchase',
            relatedId: orderData['id'] as String
          );
        }
        // 3. 现金支付 - 这里可以添加现金支付的处理逻辑
        
        
        // 3. 减少商品库存
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
        await _databaseService.updateStarProduct(updatedProduct);
      }
      
      // 4. 从购物车中删除选中的商品
      for (var cartItem in _selectedItems) {
        await _databaseService.removeFromCart(cartItem.id);
      }
      
      // 5. 清空选中状态
      setState(() {
        _selectedItemIds.clear();
        _isAllSelected = false;
      });
      
      // 6. 重新加载购物车数据
      await _loadCartItems();
      
      // 7. 显示结算成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('结算成功！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('结算失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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
                        itemCount: _cartItems.length + 1, // +1 for select all row
                        itemBuilder: (context, index) {
                          // 全选行
                          if (index == 0) {
                            return _buildSelectAllRow();
                          }
                          
                          // 商品行
                          final cartItem = _cartItems[index - 1];
                          final product = cartItem.product;
                          final quantity = cartItem.quantity;

                          return _buildCartItem(product, quantity, index - 1);
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
                  // 全选 - 添加所有商品ID到选中集合
                  _selectedItemIds = _cartItems.map((item) => item.id).toSet();
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
  Widget _buildCartItem(StarProduct product, int quantity, int index) {
    final cartItem = _cartItems[index];
    final isSelected = _selectedItemIds.contains(cartItem.id);
    
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
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedItemIds.add(cartItem.id);
                } else {
                  _selectedItemIds.remove(cartItem.id);
                }
                // 更新全选状态
                _isAllSelected = _selectedItemIds.length == _cartItems.length;
              });
            },
            activeColor: const Color(0xFF13ec5b),
            checkColor: Colors.black,
          ),
          
          const SizedBox(width: 8),
          
          // 商品图片
          GestureDetector(
            onTap: () {
              // 跳转到商品详情页
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(product: product),
                ),
              );
            },
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
                  onTap: () {
                    // 跳转到商品详情页
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(product: product),
                      ),
                    );
                  },
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
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
                              style: const TextStyle(
                                color: Color(0xFF13ec5b),
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
                          style: const TextStyle(
                            color: Color(0xFF13ec5b),
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
                          style: const TextStyle(
                            color: Color(0xFF13ec5b),
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
                            onPressed: () => _adjustQuantity(index, -1),
                            icon: const Icon(
                              Icons.remove,
                              size: 16,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(8),
                          ),

                          // 数量显示
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // 增加数量
                          IconButton(
                            onPressed: () => _adjustQuantity(index, 1),
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
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

  // 构建底部结算栏
  Widget _buildCheckoutBar() {
    // 根据选择的支付方式显示对应的总价 - 与星星商店页保持一致
    String getTotalDisplay() {
      switch (_selectedPaymentMethod) {
        case PaymentMethod.points:
          return '✨${_totalPoints}';
        case PaymentMethod.cash:
          return '¥${_totalCash}';
        case PaymentMethod.hybrid:
          return '✨${_totalHybrid['points']} + ¥${_totalHybrid['cash']}';
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
      }
    }

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
              Text(
                getTotalDisplay(),
                style: const TextStyle(
                  color: Color(0xFF13ec5b),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 结算按钮
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _checkout,
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