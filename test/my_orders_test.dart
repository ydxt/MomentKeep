import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/presentation/pages/my_orders_page.dart';
import 'package:moment_keep/presentation/pages/order_detail_page.dart';
import 'package:moment_keep/presentation/pages/after_sales_page.dart';

void main() {
  group('Order Model Tests', () {
    test('Order.fromMap should correctly create Order object', () {
      // Arrange
      final map = {
        'id': '1',
        'store_name': 'Test Store',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Act
      final order = Order.fromMap(map);

      // Assert
      expect(order.id, '1');
      expect(order.storeName, 'Test Store');
      expect(order.status, OrderStatus.completed);
    });

    test('OrderItem should correctly store item data', () {
      // Arrange & Act
      final orderItem = OrderItem(
        id: 'item1',
        name: 'Test Product',
        image: 'https://example.com/image.jpg',
        variant: 'Test Variant',
        price: 19.99,
        quantity: 2,
      );

      // Assert
      expect(orderItem.id, 'item1');
      expect(orderItem.name, 'Test Product');
      expect(orderItem.price, 19.99);
      expect(orderItem.quantity, 2);
    });

    test('LogisticsInfo should correctly store logistics data', () {
      // Arrange
      final timestamp = DateTime.now();

      // Act
      final logisticsInfo = LogisticsInfo(
        status: '运输中',
        description: '包裹正在运输',
        timestamp: timestamp,
      );

      // Assert
      expect(logisticsInfo.status, '运输中');
      expect(logisticsInfo.description, '包裹正在运输');
      expect(logisticsInfo.timestamp, timestamp);
    });
  });

  group('Order Status Tests', () {
    test('OrderStatus enum should have correct values', () {
      // Assert
      expect(OrderStatus.values.length, 9);
      expect(OrderStatus.values.contains(OrderStatus.all), true);
      expect(OrderStatus.values.contains(OrderStatus.pendingPayment), true);
      expect(OrderStatus.values.contains(OrderStatus.pendingShipment), true);
      expect(OrderStatus.values.contains(OrderStatus.pendingReceipt), true);
      expect(OrderStatus.values.contains(OrderStatus.completed), true);
      expect(OrderStatus.values.contains(OrderStatus.refundAfterSales), true);
      expect(OrderStatus.values.contains(OrderStatus.pendingReview), true);
      expect(OrderStatus.values.contains(OrderStatus.shipped), true);
      expect(OrderStatus.values.contains(OrderStatus.refunded), true);
    });

    test('OrderType enum should have correct values', () {
      // Assert
      expect(OrderType.values.length, 3);
      expect(OrderType.values.contains(OrderType.normal), true);
      expect(OrderType.values.contains(OrderType.preSale), true);
      expect(OrderType.values.contains(OrderType.flashSale), true);
    });
  });

  group('Order Operations Tests', () {
    test('AfterSalesStatus enum should have correct values', () {
      // Assert
      expect(AfterSalesStatus.values.length, 5);
      expect(AfterSalesStatus.values.contains(AfterSalesStatus.pending), true);
      expect(AfterSalesStatus.values.contains(AfterSalesStatus.processing), true);
      expect(AfterSalesStatus.values.contains(AfterSalesStatus.approved), true);
      expect(AfterSalesStatus.values.contains(AfterSalesStatus.rejected), true);
      expect(AfterSalesStatus.values.contains(AfterSalesStatus.completed), true);
    });

    test('AfterSalesType enum should have correct values', () {
      // Assert
      expect(AfterSalesType.values.length, 3);
      expect(AfterSalesType.values.contains(AfterSalesType.refund), true);
      expect(AfterSalesType.values.contains(AfterSalesType.returnGoods), true);
      expect(AfterSalesType.values.contains(AfterSalesType.repair), true);
    });
  });

  group('Widget Tests', () {
    testWidgets('MyOrdersPage should render correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: MyOrdersPage(),
        ),
      );

      // Assert
      expect(find.text('我的订单'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OrderDetailPage should render correctly', (WidgetTester tester) async {
      // Arrange
      final order = Order(
        id: '1',
        storeName: 'Test Store',
        items: [],
        totalPrice: 19.99,
        date: DateTime.now(),
        status: OrderStatus.completed,
        orderType: OrderType.normal,
        totalItems: 1,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailPage(order: order),
        ),
      );

      // Assert
      expect(find.text('订单详情'), findsOneWidget);
      expect(find.text('Test Store'), findsOneWidget);
    });
  });
}
