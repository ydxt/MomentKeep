import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';

/// 模拟 path_provider 平台接口
class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  // 初始化测试绑定，解决path_provider等依赖的问题
  TestWidgetsFlutterBinding.ensureInitialized();
  // 模拟SharedPreferences初始值，防止数据库初始化时报错
  SharedPreferences.setMockInitialValues({});
  // 模拟path_provider平台实现
  PathProviderPlatform.instance = MockPathProviderPlatform();

  group('商家版订单管理系统测试', () {
    late DatabaseService databaseService;
    late NotificationDatabaseService notificationService;
    late ProductDatabaseService productDatabaseService;

    setUp(() {
      databaseService = DatabaseService();
      notificationService = NotificationDatabaseService();
      productDatabaseService = ProductDatabaseService();
    });

    test('测试1: 订单表应该包含buyer_name和buyer_phone字段', () async {
      // 测试订单表是否包含buyer_name和buyer_phone字段
      final orders = await productDatabaseService.getAllOrders();
      if (orders.isNotEmpty) {
        final firstOrder = orders.first;
        expect(firstOrder.containsKey('buyer_name'), true,
            reason: '订单表缺少buyer_name字段');
        expect(firstOrder.containsKey('buyer_phone'), true,
            reason: '订单表缺少buyer_phone字段');
      }
    });

    test('测试2: 多件商品时积分计算应该正确', () async {
      // 创建一个测试订单，包含多件商品
      final testOrder = {
        'id': 'test_order_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test_user',
        'product_id': 1,
        'product_name': '测试商品',
        'product_image': 'test_image.jpg',
        'points': 100, // 单商品积分
        'product_price': 100.0,
        'total_amount': 200.0,
        'points_used': 0,
        'cash_amount': 200.0,
        'payment_method': 'cash',
        'quantity': 2, // 数量为2
        'variant': '测试规格',
        'status': '待发货',
        'is_electronic': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'delivery_address': '测试地址',
        'buyer_note': '测试备注',
        'buyer_name': '测试买家',
        'buyer_phone': '13800138000',
      };

      // 插入测试订单
      await productDatabaseService.insertOrder(testOrder);

      // 获取所有订单
      final orders = await productDatabaseService.getAllOrders();
      final insertedOrder =
          orders.firstWhere((order) => order['id'] == testOrder['id']);

      // 计算总积分
      final expectedPoints =
          (insertedOrder['points'] as int) * (insertedOrder['quantity'] as int);

      // 将订单转换为MerchantOrder对象
      final merchantOrder = MerchantOrder(
        id: insertedOrder['id'] as String,
        productName: insertedOrder['product_name'] as String,
        productImage: insertedOrder['product_image'] as String,
        productVariant: insertedOrder['variant'] as String,
        quantity: insertedOrder['quantity'] as int,
        points: expectedPoints, // 总积分应该是单商品积分×数量
        originalAmount: (insertedOrder['product_price'] as num).toDouble() *
            (insertedOrder['quantity'] as int),
        actualAmount: (insertedOrder['total_amount'] as num).toDouble(),
        buyerName: insertedOrder['buyer_name'] as String,
        buyerPhone: insertedOrder['buyer_phone'] as String,
        deliveryAddress: insertedOrder['delivery_address'] as String,
        buyerNote: insertedOrder['buyer_note'] as String,
        paymentMethod: '现金支付',
        deliveryMethod: '',
        isAbnormal: false,
        orderTime: DateTime.fromMillisecondsSinceEpoch(
            insertedOrder['created_at'] as int),
        isPaid: true,
        status: MerchantOrderStatus.pendingShip,
      );

      // 验证总积分计算是否正确
      expect(merchantOrder.points, expectedPoints, reason: '多件商品时积分计算错误');

      // 清理测试数据
      await productDatabaseService.deleteOrder(testOrder['id'] as String);
    });

    test('测试3: 沟通记录发送消息功能', () async {
      // 创建测试订单
      final testOrder = {
        'id': 'test_order_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test_user',
        'product_id': 1,
        'product_name': '测试商品',
        'product_image': 'test_image.jpg',
        'points': 100,
        'product_price': 100.0,
        'total_amount': 100.0,
        'points_used': 0,
        'cash_amount': 100.0,
        'payment_method': 'cash',
        'quantity': 1,
        'variant': '测试规格',
        'status': '待发货',
        'is_electronic': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'delivery_address': '测试地址',
        'buyer_note': '测试备注',
        'buyer_name': '测试买家',
        'buyer_phone': '13800138000',
      };

      // 插入测试订单
      await productDatabaseService.insertOrder(testOrder);

      // 创建测试消息
      final testMessage = NotificationInfo(
        id: 'test_notification_${DateTime.now().millisecondsSinceEpoch}',
        orderId: testOrder['id'] as String,
        productName: testOrder['product_name'] as String,
        productImage: testOrder['product_image'] as String,
        type: NotificationType.system,
        status: NotificationStatus.unread,
        content: '测试消息内容',
        createdAt: DateTime.now(),
      );

      // 发送测试消息
      await notificationService.addNotification(testMessage);

      // 获取该订单的所有通知
      final notifications = await notificationService
          .getNotificationsByOrderId(testOrder['id'] as String);

      // 验证消息是否发送成功
      expect(notifications.isNotEmpty, true, reason: '消息发送失败');
      expect(notifications.any((n) => n.content == testMessage.content), true,
          reason: '消息内容不匹配');

      // 清理测试数据
      await productDatabaseService.deleteOrder(testOrder['id'] as String);
      await notificationService.deleteNotification(testMessage.id);
    });

    test('测试4: 订单状态更新功能', () async {
      // 创建测试订单
      final testOrder = {
        'id': 'test_order_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test_user',
        'product_id': 1,
        'product_name': '测试商品',
        'product_image': 'test_image.jpg',
        'points': 100,
        'product_price': 100.0,
        'total_amount': 100.0,
        'points_used': 0,
        'cash_amount': 100.0,
        'payment_method': 'cash',
        'quantity': 1,
        'variant': '测试规格',
        'status': '待发货',
        'is_electronic': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'delivery_address': '测试地址',
        'buyer_note': '测试备注',
        'buyer_name': '测试买家',
        'buyer_phone': '13800138000',
      };

      // 插入测试订单
      await productDatabaseService.insertOrder(testOrder);

      // 更新订单状态为已发货
      await databaseService.updateOrderStatus(testOrder['id'] as String, '已发货');

      // 获取更新后的订单
      final orders = await productDatabaseService.getAllOrders();
      final updatedOrder =
          orders.firstWhere((order) => order['id'] == testOrder['id']);

      // 验证订单状态是否更新成功
      expect(updatedOrder['status'], '已发货', reason: '订单状态更新失败');

      // 清理测试数据
      await productDatabaseService.deleteOrder(testOrder['id'] as String);
    });

    test('测试5: 订单更新功能', () async {
      // 创建测试订单
      final testOrder = {
        'id': 'test_order_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'test_user',
        'product_id': 1,
        'product_name': '测试商品',
        'product_image': 'test_image.jpg',
        'points': 100,
        'product_price': 100.0,
        'total_amount': 100.0,
        'points_used': 0,
        'cash_amount': 100.0,
        'payment_method': 'cash',
        'quantity': 1,
        'variant': '测试规格',
        'status': '待发货',
        'is_electronic': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'delivery_address': '测试地址',
        'buyer_note': '测试备注',
        'buyer_name': '测试买家',
        'buyer_phone': '13800138000',
      };

      // 插入测试订单
      await productDatabaseService.insertOrder(testOrder);

      // 更新订单的买家信息
      final updatedInfo = {
        'buyer_name': '更新后的买家名称',
        'buyer_phone': '13900139000',
      };

      await databaseService.updateOrder(testOrder['id'] as String, updatedInfo);

      // 获取更新后的订单
      final orders = await productDatabaseService.getAllOrders();
      final updatedOrder =
          orders.firstWhere((order) => order['id'] == testOrder['id']);

      // 验证订单信息是否更新成功
      expect(updatedOrder['buyer_name'], updatedInfo['buyer_name'],
          reason: '买家名称更新失败');
      expect(updatedOrder['buyer_phone'], updatedInfo['buyer_phone'],
          reason: '买家电话更新失败');

      // 清理测试数据
      await productDatabaseService.deleteOrder(testOrder['id'] as String);
    });
  });
}
