import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';

void main() {
  group('DrawingPoint Tests', () {
    test('DrawingPoint creation and properties', () {
      final point = DrawingPoint(
        offset: const Offset(10.0, 20.0),
        color: Colors.red,
        width: 5.0,
      );
      
      expect(point.offset.dx, equals(10.0));
      expect(point.offset.dy, equals(20.0));
      expect(point.color, equals(Colors.red));
      expect(point.width, equals(5.0));
      expect(point.isEndOfStroke, equals(false));
    });
    
    test('DrawingPoint.endOfStroke creation', () {
      final endPoint = DrawingPoint.endOfStroke(Colors.blue, 3.0);
      
      expect(endPoint.isEndOfStroke, equals(true));
      expect(endPoint.color, equals(Colors.blue));
      expect(endPoint.width, equals(3.0));
    });
    
    test('DrawingPoint toJson and fromJson serialization', () {
      final originalPoint = DrawingPoint(
        offset: const Offset(15.5, 25.5),
        color: Colors.green.shade500, // 使用普通 Color 而非 MaterialColor
        width: 4.5,
        isEndOfStroke: false,
      );
      
      final json = originalPoint.toJson();
      final deserializedPoint = DrawingPoint.fromJson(json);
      
      expect(deserializedPoint.offset.dx, equals(15.5));
      expect(deserializedPoint.offset.dy, equals(25.5));
      expect(deserializedPoint.color.value, equals(Colors.green.shade500.value)); // 比较颜色值而非对象类型
      expect(deserializedPoint.width, equals(4.5));
      expect(deserializedPoint.isEndOfStroke, equals(false));
    });
    
    test('DrawingPoint comparison', () {
      final point1 = DrawingPoint(
        offset: const Offset(10.0, 20.0),
        color: Colors.red,
        width: 5.0,
      );
      
      final point2 = DrawingPoint(
        offset: const Offset(10.0, 20.0),
        color: Colors.red,
        width: 5.0,
      );
      
      final point3 = DrawingPoint(
        offset: const Offset(30.0, 40.0),
        color: Colors.blue,
        width: 3.0,
      );
      
      expect(point1, equals(point2));
      expect(point1.hashCode, equals(point2.hashCode));
      expect(point1, isNot(equals(point3)));
    });
    
    test('DrawingPoint handles invalid data gracefully', () {
      // Test with null values
      final invalidJson = {'dx': null, 'dy': null, 'color': null, 'width': null, 'isEndOfStroke': null};
      final point = DrawingPoint.fromJson(invalidJson);
      
      // 确保返回了一个有效的点对象
      expect(point.isEndOfStroke, isA<bool>());
      expect(point.width, isA<double>());
      expect(point.color, isA<Color>());
    });
    
    test('DrawingPoint toJson handles invalid offsets', () {
      final point = DrawingPoint(
        offset: const Offset(double.infinity, double.nan),
        color: Colors.red,
        width: double.negativeInfinity,
      );
      
      final json = point.toJson();
      
      expect(json['dx'], equals(0.0));
      expect(json['dy'], equals(0.0));
      expect(json['width'], equals(3.0));
    });
  });
  
  group('Drawing Functionality Tests', () {
    test('DrawingPoint validation logic', () {
      // Test that invalid points are handled correctly
      final validPoint = DrawingPoint(
        offset: const Offset(10.0, 20.0),
        color: Colors.red,
        width: 5.0,
      );
      
      // This test ensures that our DrawingPoint class can handle various edge cases
      expect(validPoint.offset.dx.isFinite, isTrue);
      expect(validPoint.offset.dy.isFinite, isTrue);
      expect(validPoint.width.isFinite, isTrue);
    });
    
    test('DrawingPoint end of stroke handling', () {
      // Test that end of stroke points are correctly identified
      final endPoint = DrawingPoint.endOfStroke(Colors.blue, 3.0);
      
      expect(endPoint.isEndOfStroke, isTrue);
    });
  });
}