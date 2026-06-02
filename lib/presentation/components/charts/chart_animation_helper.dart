import 'package:flutter/animation.dart';

/// 图表动画辅助工具
/// 提供时间轴切换过渡动画、卡片入场动画等
class ChartAnimationHelper {
  /// 默认动画时长
  static const Duration defaultDuration = Duration(milliseconds: 600);

  /// 短动画时长
  static const Duration shortDuration = Duration(milliseconds: 300);

  /// 长动画时长
  static const Duration longDuration = Duration(milliseconds: 900);

  /// 默认缓动曲线
  static const Curve defaultCurve = Curves.easeInOutCubic;

  /// 弹性缓动曲线
  static const Curve springCurve = Curves.elasticOut;

  /// 减速缓动曲线
  static const Curve decelerateCurve = Curves.decelerate;

  /// 计算三次贝塞尔曲线控制点
  /// [points] 数据点列表
  /// [tension] 曲线张力，0.0=直线，1.0=极度弯曲，推荐0.35
  static List<Offset> calculateBezierControlPoints(
    List<Offset> points, {
    double tension = 0.35,
  }) {
    final controlPoints = <Offset>[];
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) * tension,
        p1.dy + (p2.dy - p0.dy) * tension,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) * tension,
        p2.dy - (p3.dy - p1.dy) * tension,
      );
      controlPoints.add(cp1);
      controlPoints.add(cp2);
    }
    return controlPoints;
  }

  /// 数据点插值
  /// 用于动画过渡时在旧数据和新数据之间平滑插值
  /// [oldData] 旧数据
  /// [newData] 新数据
  /// [t] 插值因子 0.0-1.0
  static List<double> interpolateData(
    List<double> oldData,
    List<double> newData,
    double t,
  ) {
    final maxLen = oldData.length > newData.length
        ? oldData.length
        : newData.length;
    final result = <double>[];
    for (int i = 0; i < maxLen; i++) {
      final oldVal = i < oldData.length ? oldData[i] : oldData.isNotEmpty ? oldData.last : 0.0;
      final newVal = i < newData.length ? newData[i] : newData.isNotEmpty ? newData.last : 0.0;
      result.add(oldVal + (newVal - oldVal) * t);
    }
    return result;
  }

  /// 计算交错动画延迟
  /// [index] 项目索引
  /// [totalItems] 总项目数
  /// [baseDelay] 基础延迟（毫秒）
  /// [staggerDelay] 每项递增延迟（毫秒）
  static Duration staggerDelay({
    required int index,
    int baseDelay = 100,
    int staggerDelay = 80,
  }) {
    return Duration(milliseconds: baseDelay + index * staggerDelay);
  }

  /// 计算环形图动画进度
  /// [animationValue] 动画值 0.0-1.0
  /// [segmentIndex] 段索引
  /// [totalSegments] 总段数
  /// 返回该段应绘制的角度比例 0.0-1.0
  static double donutSegmentProgress(
    double animationValue,
    int segmentIndex,
    int totalSegments,
  ) {
    final segmentDuration = 1.0 / totalSegments;
    final segmentStart = segmentIndex * segmentDuration;
    final segmentEnd = segmentStart + segmentDuration;

    if (animationValue <= segmentStart) return 0.0;
    if (animationValue >= segmentEnd) return 1.0;

    final localProgress = (animationValue - segmentStart) / segmentDuration;
    return Curves.easeOut.transform(localProgress);
  }
}
