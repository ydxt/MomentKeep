import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:moment_keep/presentation/components/charts/chart_gradient_palette.dart';

/// 柱状图数据项
class BarDataItem {
  /// 标签
  final String label;

  /// 数值
  final double value;

  /// 颜色
  final Color color;

  /// 构造函数
  const BarDataItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// 通用柱状图组件
/// 用于完成时段分布、月度写作频次等
class PremiumBarChart extends StatefulWidget {
  /// 数据项列表
  final List<BarDataItem> items;

  /// 图表标题
  final String title;

  /// 图表高度
  final double height;

  /// 柱子最大宽度
  final double maxBarWidth;

  /// 柱子圆角
  final double barRadius;

  /// 是否显示数值标签
  final bool showValueLabel;

  /// 是否显示渐变
  final bool showGradient;

  /// Y轴标签后缀
  final String ySuffix;

  /// 构造函数
  const PremiumBarChart({
    super.key,
    required this.items,
    this.title = '',
    this.height = 160,
    this.maxBarWidth = 40,
    this.barRadius = 6,
    this.showValueLabel = true,
    this.showGradient = true,
    this.ySuffix = '',
  });

  @override
  State<PremiumBarChart> createState() => _PremiumBarChartState();
}

class _PremiumBarChartState extends State<PremiumBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _maxValue {
    if (widget.items.isEmpty) return 1;
    return widget.items.map((i) => i.value).reduce(math.max) * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(widget.title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                )),
          ),
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _BarPainter(
                  items: widget.items,
                  maxValue: _maxValue,
                  animProgress: _animation.value,
                  hoveredIndex: _hoveredIndex,
                  maxBarWidth: widget.maxBarWidth,
                  barRadius: widget.barRadius,
                  showValueLabel: widget.showValueLabel,
                  showGradient: widget.showGradient,
                  ySuffix: widget.ySuffix,
                  theme: theme,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 柱状图绘制器
class _BarPainter extends CustomPainter {
  final List<BarDataItem> items;
  final double maxValue;
  final double animProgress;
  final int? hoveredIndex;
  final double maxBarWidth;
  final double barRadius;
  final bool showValueLabel;
  final bool showGradient;
  final String ySuffix;
  final ThemeData theme;

  _BarPainter({
    required this.items,
    required this.maxValue,
    required this.animProgress,
    required this.hoveredIndex,
    required this.maxBarWidth,
    required this.barRadius,
    required this.showValueLabel,
    required this.showGradient,
    required this.ySuffix,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final plotLeft = 40.0;
    final plotRight = size.width - 10.0;
    final plotTop = 10.0;
    final plotBottom = size.height - 28.0;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final gridPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = plotTop + (i / 4) * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);

      final value = maxValue - (i / 4) * maxValue;
      final tp = TextPainter(
        text: TextSpan(
          text: '${value.toInt()}$ySuffix',
          style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(plotLeft - tp.width - 6, y - tp.height / 2));
    }

    final barSpacing = plotWidth / items.length;
    final barWidth = (barSpacing * 0.6).clamp(8.0, maxBarWidth);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isHovered = hoveredIndex == i;
      final barHeight =
          (item.value / maxValue) * plotHeight * animProgress;
      final barX = plotLeft + i * barSpacing + (barSpacing - barWidth) / 2;
      final barY = plotBottom - barHeight;

      if (barHeight > 0) {
        final rect = Rect.fromLTWH(barX, barY, barWidth, barHeight);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(barRadius),
          topRight: Radius.circular(barRadius),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        );

        if (showGradient) {
          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              item.color,
              item.color.withOpacity(0.6),
            ],
          );
          final paint = Paint()
            ..shader = gradient.createShader(rect)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(rrect, paint);
        } else {
          final paint = Paint()
            ..color = item.color
            ..style = PaintingStyle.fill;
          canvas.drawRRect(rrect, paint);
        }

        if (isHovered) {
          final glowPaint = Paint()
            ..color = item.color.withOpacity(0.15)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
          canvas.drawRRect(rrect, glowPaint);
        }

        if (showValueLabel && barHeight > 16) {
          final tp = TextPainter(
            text: TextSpan(
              text: item.value.toInt().toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas,
              Offset(barX + barWidth / 2 - tp.width / 2, barY + 4));
        }
      }

      final labelTp = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            color: isHovered
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      labelTp.layout(maxWidth: barSpacing - 4);
      labelTp.paint(canvas,
          Offset(barX + barWidth / 2 - labelTp.width / 2, plotBottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.items != items;
  }
}
