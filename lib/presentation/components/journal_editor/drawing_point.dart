import 'package:flutter/material.dart';

/// 绘图点数据类
class DrawingPoint {
  final Offset offset;
  final Color color;
  final double width;
  final bool isEndOfStroke;

  DrawingPoint({
    required this.offset,
    required this.color,
    required this.width,
    this.isEndOfStroke = false,
  });

  // 创建笔触结束标记点，不再使用 NaN
  factory DrawingPoint.endOfStroke(Color color, double width) {
    return DrawingPoint(
      offset: Offset.zero, // 使用零值标记结束点，通过 isEndOfStroke 标记识别
      color: color,
      width: width,
      isEndOfStroke: true,
    );
  }

  Map<String, dynamic> toJson() {
    // 安全的 toJson 实现，确保不会写入 NaN 或无效值
    return {
      'dx': offset.dx.isFinite ? offset.dx : 0.0,
      'dy': offset.dy.isFinite ? offset.dy : 0.0,
      'color': color.toARGB32(),
      'width': width.isFinite ? width : 3.0,
      'isEndOfStroke': isEndOfStroke,
    };
  }

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    // 增强的安全检查，确保能处理各种异常情况
    try {
      // 提取值并提供安全默认值
      final dx = json['dx'];
      final dy = json['dy'];

      // 转换为 double 并确保是有限值
      final double dxDouble =
          dx is num ? (dx.toDouble().isFinite ? dx.toDouble() : 0.0) : 0.0;
      final double dyDouble =
          dy is num ? (dy.toDouble().isFinite ? dy.toDouble() : 0.0) : 0.0;

      // 提取颜色并确保有效
      final colorValue = json['color'];
      final Color color = colorValue is int ? Color(colorValue) : Colors.black;

      // 提取宽度并确保是有限值
      final widthValue = json['width'];
      final double width = widthValue is num
          ? (widthValue.toDouble().isFinite ? widthValue.toDouble() : 3.0)
          : 3.0;

      // 提取 isEndOfStroke 并确保是布尔值
      final isEndOfStrokeValue = json['isEndOfStroke'];
      final bool isEndOfStroke =
          isEndOfStrokeValue is bool ? isEndOfStrokeValue : false;

      return DrawingPoint(
        offset: Offset(dxDouble, dyDouble),
        color: color,
        width: width,
        isEndOfStroke: isEndOfStroke,
      );
    } catch (e) {
      // 如果解析失败，返回一个安全的默认值
      return DrawingPoint(
        offset: Offset.zero,
        color: Colors.black,
        width: 3.0,
        isEndOfStroke: true,
      );
    }
  }

  // 重写 == 运算符，确保能正确比较绘图点
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is DrawingPoint) {
      return offset.dx == other.offset.dx &&
          offset.dy == other.offset.dy &&
          color == other.color &&
          width == other.width &&
          isEndOfStroke == other.isEndOfStroke;
    }
    return false;
  }

  // 重写 hashCode 方法，确保能正确比较绘图点
  @override
  int get hashCode {
    return Object.hash(offset.dx, offset.dy, color, width, isEndOfStroke);
  }
}
