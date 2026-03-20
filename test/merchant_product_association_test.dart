import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

void main() {
  group('商家商品关联 - 实体类单元测试', () {
    test('测试1: StarProduct 实体应包含 merchantId 字段', () {
      final product = StarProduct(
        id: 1,
        name: '测试商品',
        image: 'test.jpg',
        productCode: 'TEST001',
        points: 100,
        costPrice: 50,
        stock: 10,
        categoryId: 1,
        merchantId: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.merchantId, 100);
      expect(product.merchantId, isNotNull);
    });

    test('测试2: StarProduct toMap/fromMap 应正确处理 merchantId', () {
      final product = StarProduct(
        id: 1,
        name: '测试商品',
        image: 'test.jpg',
        productCode: 'TEST001',
        points: 100,
        costPrice: 50,
        stock: 10,
        categoryId: 1,
        merchantId: 200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = product.toMap();
      expect(map['merchant_id'], 200);

      final restored = StarProduct.fromMap(map);
      expect(restored.merchantId, 200);
    });

    test('测试3: StarProduct merchantId 可以为 null', () {
      final product = StarProduct(
        id: 1,
        name: '测试商品',
        image: 'test.jpg',
        productCode: 'TEST001',
        points: 100,
        costPrice: 50,
        stock: 10,
        categoryId: 1,
        merchantId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.merchantId, isNull);

      final map = product.toMap();
      expect(map['merchant_id'], isNull);

      final restored = StarProduct.fromMap(map);
      expect(restored.merchantId, isNull);
    });

    test('测试4: StarProduct 默认 merchantId 为 null', () {
      final product = StarProduct(
        id: 1,
        name: '测试商品',
        image: 'test.jpg',
        productCode: 'TEST001',
        points: 100,
        costPrice: 50,
        stock: 10,
        categoryId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.merchantId, isNull);
    });

    test('测试5: StarProduct 复制时 merchantId 保持不变', () {
      final product = StarProduct(
        id: 1,
        name: '测试商品',
        image: 'test.jpg',
        productCode: 'TEST001',
        points: 100,
        costPrice: 50,
        stock: 10,
        categoryId: 1,
        merchantId: 300,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = product.toMap();
      final restored = StarProduct.fromMap(map);

      expect(restored.merchantId, product.merchantId);
      expect(restored.merchantId, 300);
    });
  });

  group('商家实体测试', () {
    test('测试6: Merchant 实体可以正常创建', () {
      final merchant = Merchant(
        id: 1,
        userId: 'user123',
        name: '测试商家',
        description: '这是一个测试商家',
        phone: '13800138000',
        email: 'test@example.com',
        address: '测试地址',
        status: 'active',
        rating: 4.5,
        totalSales: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(merchant.name, '测试商家');
      expect(merchant.userId, 'user123');
      expect(merchant.status, 'active');
    });

    test('测试7: Merchant toMap/fromMap 正确序列化', () {
      final merchant = Merchant(
        id: 1,
        userId: 'user456',
        name: '测试商家2',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = merchant.toMap();
      final restored = Merchant.fromMap(map);

      expect(restored.userId, merchant.userId);
      expect(restored.name, merchant.name);
    });
  });
}
