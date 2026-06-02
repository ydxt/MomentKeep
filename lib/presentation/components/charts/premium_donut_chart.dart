import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:moment_keep/presentation/components/charts/chart_gradient_palette.dart';
import 'package:moment_keep/presentation/components/charts/chart_animation_helper.dart';

/// 环形图数据段
class DonutSegment {
  /// 段标签
  final String label;

  /// 段数值
  final double value;

  /// 段颜色
  final Color color;

  /// 段图标（可选）
  final IconData? icon;

  /// 构造函数
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });
}

/// 通用环形图组件
/// 用于优先级分布、分类分布、心情分布、积分来源/消耗等
class PremiumDonutChart extends StatefulWidget {
  /// 数据段列表
  final List<DonutSegment> segments;

  /// 中心显示主文字
  final String? centerText;

  /// 中心显示副文字
  final String? centerSubText;

  /// 图表尺寸
  final double size;

  /// 环形宽度
  final double ringWidth;

  /// 是否显示图例
  final bool showLegend;

  /// 动画时长
  final Duration animationDuration;

  /// 段间距（度数）
  final double segmentGap;

  /// 构造函数
  const PremiumDonutChart({
    super.key,
    required this.segments,
    this.centerText,
    this.centerSubText,
    this.size = 140,
    this.ringWidth = 18,
    this.showLegend = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.segmentGap = 2.0,
  });

  @override
  State<PremiumDonutChart> createState() => _PremiumDonutChartState();
}

class _PremiumDonutChartState extends State<PremiumDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _totalValue {
    return widget.segments.fold(0.0, (sum, s) => sum + s.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.segments.isEmpty || _totalValue == 0) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 8),
              Text('暂无数据',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: MouseRegion(
                onHover: (details) {
                  final center = Offset(widget.size / 2, widget.size / 2);
                  final dx = details.localPosition.dx - center.dx;
                  final dy = details.localPosition.dy - center.dy;
                  final distance = math.sqrt(dx * dx + dy * dy);
                  final outerRadius = widget.size / 2;
                  final innerRadius = outerRadius - widget.ringWidth;

                  if (distance < innerRadius || distance > outerRadius) {
                    if (_hoveredIndex != null) {
                      setState(() => _hoveredIndex = null);
                    }
                    return;
                  }

                  var angle = math.atan2(dy, dx);
                  if (angle < -math.pi / 2) angle += 2 * math.pi;
                  final normalizedAngle =
                      (angle + math.pi / 2) % (2 * math.pi);

                  double cumAngle = 0;
                  int? foundIndex;
                  for (int i = 0; i < widget.segments.length; i++) {
                    final segAngle =
                        (widget.segments[i].value / _totalValue) * 2 * math.pi;
                    if (normalizedAngle >= cumAngle &&
                        normalizedAngle < cumAngle + segAngle) {
                      foundIndex = i;
                      break;
                    }
                    cumAngle += segAngle;
                  }

                  if (foundIndex != _hoveredIndex) {
                    setState(() => _hoveredIndex = foundIndex);
                  }
                },
                onExit: (_) {
                  if (_hoveredIndex != null) {
                    setState(() => _hoveredIndex = null);
                  }
                },
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: widget.segments,
                    totalValue: _totalValue,
                    centerText: widget.centerText,
                    centerSubText: widget.centerSubText,
                    ringWidth: widget.ringWidth,
                    segmentGap: widget.segmentGap,
                    animProgress: _animation.value,
                    hoveredIndex: _hoveredIndex,
                    theme: theme,
                  ),
                  size: Size(widget.size, widget.size),
                ),
              ),
            );
          },
        ),
        if (widget.showLegend) const SizedBox(width: 16),
        if (widget.showLegend)
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.size),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: widget.segments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final segment = entry.value;
                    final percentage =
                        _totalValue > 0 ? (segment.value / _totalValue * 100) : 0;
                    final isHovered = _hoveredIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: segment.color,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isHovered
                                  ? [
                                      BoxShadow(
                                        color: segment.color.withOpacity(0.4),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              segment.label,
                              style: TextStyle(
                                color: isHovered
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight:
                                    isHovered ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: isHovered
                              ? segment.color
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ],
    );
  }
}

/// 环形图绘制器
class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double totalValue;
  final String? centerText;
  final String? centerSubText;
  final double ringWidth;
  final double segmentGap;
  final double animProgress;
  final int? hoveredIndex;
  final ThemeData theme;

  _DonutPainter({
    required this.segments,
    required this.totalValue,
    required this.centerText,
    required this.centerSubText,
    required this.ringWidth,
    required this.segmentGap,
    required this.animProgress,
    required this.hoveredIndex,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty || totalValue == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - ringWidth;

    final totalGap = segmentGap * segments.length;
    final availableAngle = (2 * math.pi - totalGap * math.pi / 180) * animProgress;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final sweepAngle =
          (segment.value / totalValue) * availableAngle;
      final isHovered = hoveredIndex == i;
      final extraRadius = isHovered ? 3.0 : 0.0;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth + extraRadius
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: (outerRadius + innerRadius) / 2),
        startAngle,
        sweepAngle - (segmentGap * math.pi / 180),
        false,
        paint,
      );

      if (isHovered) {
        final glowPaint = Paint()
          ..color = segment.color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth + 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawArc(
          Rect.fromCircle(
              center: center, radius: (outerRadius + innerRadius) / 2),
          startAngle,
          sweepAngle - (segmentGap * math.pi / 180),
          false,
          glowPaint,
        );
      }

      startAngle += sweepAngle;
    }

    if (centerText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: centerText,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final yOffset =
          centerSubText != null ? -tp.height / 2 - 4 : -tp.height / 2;
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + yOffset));
    }

    if (centerSubText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: centerSubText,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final yOffset = centerText != null ? 4 : -tp.height / 2;
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + yOffset));
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.segments != segments;
  }
}
