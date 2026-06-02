import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:moment_keep/presentation/components/charts/chart_gradient_palette.dart';
import 'package:moment_keep/presentation/components/charts/chart_animation_helper.dart';

/// 图表数据系列
class ChartSeries {
  /// 唯一标识
  final String id;

  /// 系列名称
  final String name;

  /// 系列颜色
  final Color color;

  /// 数据值列表
  final List<double> values;

  /// 最大值（用于归一化）
  final int? maxValue;

  /// 构造函数
  const ChartSeries({
    required this.id,
    required this.name,
    required this.color,
    required this.values,
    this.maxValue,
  });
}

/// 通用高级趋势图组件
/// 统一替代 _TodoTrendChart, _DiaryTrendChart, _EnhancedTrendChart
/// 支持贝塞尔平滑、渐变填充、发光效果、多系列、归一化
class PremiumTrendChart extends StatefulWidget {
  /// 数据系列列表（支持多线）
  final List<ChartSeries> series;

  /// X轴日期标签
  final List<String> dates;

  /// 图表标题
  final String title;

  /// 是否显示归一化开关
  final bool showNormalizeSwitch;

  /// 是否显示筛选菜单
  final bool showFilterMenu;

  /// 是否显示渐变填充
  final bool showGradientFill;

  /// 是否显示发光效果
  final bool showGlowEffect;

  /// 贝塞尔曲线张力 (0.0-1.0, 推荐0.35)
  final double curveTension;

  /// 图表高度
  final double height;

  /// 是否显示数据点
  final bool showDots;

  /// 是否紧凑模式（用于嵌入卡片内）
  final bool compact;

  /// 时间范围切换回调
  final ValueChanged<String>? onTimeRangeChanged;

  /// 构造函数
  const PremiumTrendChart({
    super.key,
    required this.series,
    required this.dates,
    required this.title,
    this.showNormalizeSwitch = false,
    this.showFilterMenu = false,
    this.showGradientFill = true,
    this.showGlowEffect = true,
    this.curveTension = 0.35,
    this.height = 200,
    this.showDots = false,
    this.compact = false,
    this.onTimeRangeChanged,
  });

  @override
  State<PremiumTrendChart> createState() => _PremiumTrendChartState();
}

class _PremiumTrendChartState extends State<PremiumTrendChart>
    with SingleTickerProviderStateMixin {
  bool _normalized = false;
  List<String> _selectedSeries = [];
  Map<String, List<double>> _seriesValues = {};
  int? _hoverIndex;
  late AnimationController _animController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: ChartAnimationHelper.longDuration,
      vsync: this,
    );
    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _initializeData();
    _selectedSeries = widget.series.map((s) => s.id).toList();
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series || oldWidget.dates != widget.dates) {
      _initializeData();
      _selectedSeries = widget.series.map((s) => s.id).toList();
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _initializeData() {
    _seriesValues = {};
    for (final s in widget.series) {
      _seriesValues[s.id] = List<double>.from(s.values);
    }
  }

  void _updateChartData() {
    _seriesValues = {};
    for (final s in widget.series) {
      _seriesValues[s.id] = [];
      for (int i = 0; i < s.values.length; i++) {
        double value = s.values[i];
        if (_normalized && s.maxValue != null && s.maxValue! > 0) {
          value = (value / s.maxValue!) * 100;
        }
        _seriesValues[s.id]!.add(value);
      }
    }
  }

  double get _minY {
    double min = double.infinity;
    for (final id in _selectedSeries) {
      if (_seriesValues.containsKey(id)) {
        for (final v in _seriesValues[id]!) {
          if (v < min) min = v;
        }
      }
    }
    if (min == double.infinity) return 0;
    if (min >= 0) return 0;
    final padding = min.abs() * 0.15;
    return (min - padding).floorToDouble();
  }

  double get _maxY {
    double max = -double.infinity;
    for (final id in _selectedSeries) {
      if (_seriesValues.containsKey(id)) {
        for (final v in _seriesValues[id]!) {
          if (v > max) max = v;
        }
      }
    }
    if (max == -double.infinity) return 5;
    if (max <= 0) return 0;
    final padding = max * 0.15;
    return (max + padding).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minY = _minY;
    final maxY = _maxY;
    final hasNegative = minY < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.compact) _buildHeader(theme),
        if (!widget.compact) const SizedBox(height: 12),
        SizedBox(
          height: widget.compact ? widget.height : widget.height - 50,
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return MouseRegion(
                onHover: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  final chartWidth = renderBox.size.width;
                  final plotLeft = 45.0;
                  final plotWidth = chartWidth - plotLeft - 10;
                  final dx = details.localPosition.dx - plotLeft;
                  if (dx >= 0 && widget.dates.isNotEmpty) {
                    final spacing =
                        plotWidth / (widget.dates.length - 1).clamp(1, 99999);
                    final idx =
                        (dx / spacing).round().clamp(0, widget.dates.length - 1);
                    setState(() => _hoverIndex = idx);
                  }
                },
                onExit: (_) => setState(() => _hoverIndex = null),
                child: CustomPaint(
                  painter: _PremiumTrendPainter(
                    seriesValues: _seriesValues,
                    seriesList: widget.series,
                    selectedSeries: _selectedSeries,
                    dates: widget.dates,
                    minY: minY,
                    maxY: maxY,
                    hasNegative: hasNegative,
                    normalized: _normalized,
                    theme: theme,
                    hoverIndex: _hoverIndex,
                    showGradientFill: widget.showGradientFill,
                    showGlowEffect: widget.showGlowEffect,
                    showDots: widget.showDots,
                    curveTension: widget.curveTension,
                    animProgress: _chartAnimation.value,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
        if (_selectedSeries.isNotEmpty && !widget.compact)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 24,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedSeries.length,
                itemBuilder: (context, index) {
                  final seriesId = _selectedSeries[index];
                  final series = widget.series.firstWhere(
                    (s) => s.id == seriesId,
                    orElse: () => ChartSeries(
                      id: '',
                      name: '',
                      color: theme.colorScheme.primary,
                      values: [],
                    ),
                  );
                  final isNeg =
                      (_seriesValues[seriesId] ?? []).any((v) => v < 0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isNeg
                              ? ChartGradientPalette.negativeColor
                              : series.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(series.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          )),
                    ]),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            )),
        Row(
          children: [
            if (widget.showNormalizeSwitch)
              Row(children: [
                Text('归一化',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    )),
                const SizedBox(width: 4),
                Switch(
                  value: _normalized,
                  onChanged: (value) {
                    setState(() {
                      _normalized = value;
                      _updateChartData();
                    });
                  },
                  activeColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
            if (widget.showFilterMenu && widget.series.length > 1)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant, size: 18),
                itemBuilder: (context) => _buildFilterMenu(theme),
                padding: const EdgeInsets.all(4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildFilterMenu(ThemeData theme) {
    final items = <PopupMenuEntry<String>>[];
    items.add(PopupMenuItem<String>(
      value: 'all',
      child: Row(
        children: [
          Checkbox(
            value: _selectedSeries.length == widget.series.length,
            onChanged: (value) {
              setState(() {
                _selectedSeries = value == true
                    ? widget.series.map((s) => s.id).toList()
                    : [];
              });
              Navigator.of(context).pop();
            },
            activeColor: theme.colorScheme.primary,
          ),
          Text('全部', style: TextStyle(color: theme.colorScheme.onSurface)),
        ],
      ),
    ));
    items.add(const PopupMenuDivider());
    for (final s in widget.series) {
      final isSelected = _selectedSeries.contains(s.id);
      items.add(PopupMenuItem<String>(
        value: s.id,
        height: 44,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSeries.add(s.id);
                  } else {
                    _selectedSeries.remove(s.id);
                  }
                });
                Navigator.of(context).pop();
              },
              activeColor: s.color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(s.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface, fontSize: 13)),
            ),
          ],
        ),
      ));
    }
    return items;
  }
}

/// 高级趋势图绘制器
/// 支持贝塞尔平滑、渐变填充、发光效果
class _PremiumTrendPainter extends CustomPainter {
  final Map<String, List<double>> seriesValues;
  final List<ChartSeries> seriesList;
  final List<String> selectedSeries;
  final List<String> dates;
  final double minY;
  final double maxY;
  final bool hasNegative;
  final bool normalized;
  final ThemeData theme;
  final int? hoverIndex;
  final bool showGradientFill;
  final bool showGlowEffect;
  final bool showDots;
  final double curveTension;
  final double animProgress;

  _PremiumTrendPainter({
    required this.seriesValues,
    required this.seriesList,
    required this.selectedSeries,
    required this.dates,
    required this.minY,
    required this.maxY,
    required this.hasNegative,
    required this.normalized,
    required this.theme,
    required this.hoverIndex,
    required this.showGradientFill,
    required this.showGlowEffect,
    required this.showDots,
    required this.curveTension,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty || selectedSeries.isEmpty) return;

    final plotLeft = 45.0;
    final plotRight = size.width - 10.0;
    final plotTop = 10.0;
    final plotBottom = size.height - 30.0;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    final valueRange = maxY - minY;
    if (valueRange <= 0) return;

    double valueToY(double v) {
      return plotBottom - ((v - minY) / valueRange) * plotHeight;
    }

    double indexToX(int i) {
      if (dates.length == 1) return plotLeft + plotWidth / 2;
      return plotLeft + (i / (dates.length - 1)) * plotWidth;
    }

    _drawGrid(canvas, plotLeft, plotRight, plotTop, plotBottom, plotWidth,
        plotHeight, valueRange);
    _drawZeroLine(canvas, plotLeft, plotRight, plotTop, plotBottom, valueToY);
    _drawBorder(canvas, plotLeft, plotTop, plotRight, plotBottom);
    _drawYLabels(canvas, plotLeft, plotTop, plotHeight, valueRange);
    _drawXLabels(canvas, plotBottom, indexToX);

    final visibleCount =
        (dates.length * animProgress).round().clamp(1, dates.length);

    for (final seriesId in selectedSeries) {
      final values = seriesValues[seriesId];
      final series = seriesList.firstWhere(
        (s) => s.id == seriesId,
        orElse: () => ChartSeries(
            id: '', name: '', color: theme.colorScheme.primary, values: []),
      );
      if (values == null || values.isEmpty) continue;

      final points = <Offset>[];
      for (int i = 0; i < visibleCount && i < values.length; i++) {
        final x = indexToX(i);
        final y = valueToY(values[i]);
        points.add(Offset(x, y));
      }

      if (points.length < 2) continue;

      final controlPoints =
          ChartAnimationHelper.calculateBezierControlPoints(
        points,
        tension: curveTension,
      );

      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final cp1 = controlPoints[i * 2];
        final cp2 = controlPoints[i * 2 + 1];
        path.cubicTo(
            cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
      }

      if (showGradientFill) {
        _drawGradientFill(canvas, path, plotLeft, plotRight, plotBottom,
            plotTop, series.color);
      }

      if (showGlowEffect) {
        _drawGlowLine(canvas, path, series.color);
      } else {
        final linePaint = Paint()
          ..color = series.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, linePaint);
      }

      if (showDots) {
        for (int i = 0; i < points.length; i++) {
          final isHovered = i == hoverIndex;
          final radius = isHovered ? 5.0 : 3.0;
          canvas.drawCircle(
              points[i], radius, Paint()..color = series.color);
          if (isHovered) {
            canvas.drawCircle(points[i], radius,
                Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);
            canvas.drawCircle(
                points[i], radius, Paint()..color = series.color);
          }
        }
      }
    }

    if (hoverIndex != null && hoverIndex! < dates.length) {
      _drawHoverTooltip(canvas, indexToX, plotLeft, plotRight, plotTop,
          plotBottom, valueToY);
    }
  }

  void _drawGrid(Canvas canvas, double plotLeft, double plotRight,
      double plotTop, double plotBottom, double plotWidth, double plotHeight,
      double valueRange) {
    final gridPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.12)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = plotTop + (i / 4) * plotHeight;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
    }

    if (dates.length > 7) {
      final vInterval = (dates.length / 6).floor();
      for (int i = 0; i < dates.length; i += vInterval) {
        final x = plotLeft + (i / (dates.length - 1).clamp(1, 99999)) * plotWidth;
        canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), gridPaint);
      }
    }
  }

  void _drawZeroLine(Canvas canvas, double plotLeft, double plotRight,
      double plotTop, double plotBottom, double Function(double) valueToY) {
    if (!hasNegative || minY >= 0 || maxY <= 0) return;
    final zeroY = valueToY(0);
    final zeroPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double startX = plotLeft;
    while (startX < plotRight) {
      final endX = startX + 6;
      canvas.drawLine(Offset(startX, zeroY),
          Offset(endX.clamp(plotLeft, plotRight), zeroY), zeroPaint);
      startX = endX + 4;
    }

    final negFillPaint = Paint()
      ..color = ChartGradientPalette.negativeColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTRB(plotLeft, zeroY, plotRight, plotBottom), negFillPaint);

    final posFillPaint = Paint()
      ..color = ChartGradientPalette.positiveColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTRB(plotLeft, plotTop, plotRight, zeroY), posFillPaint);
  }

  void _drawBorder(Canvas canvas, double plotLeft, double plotTop,
      double plotRight, double plotBottom) {
    final borderPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom), borderPaint);
  }

  void _drawYLabels(Canvas canvas, double plotLeft, double plotTop,
      double plotHeight, double valueRange) {
    for (int i = 0; i <= 4; i++) {
      final value = maxY - (i / 4) * valueRange;
      final y = plotTop + (i / 4) * plotHeight;
      String label = value.toInt().toString();
      if (normalized) label = '$label%';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(plotLeft - tp.width - 8, y - tp.height / 2));
    }
  }

  void _drawXLabels(Canvas canvas, double plotBottom,
      double Function(int) indexToX) {
    int labelInterval = (dates.length / 5).ceil();
    if (labelInterval < 1) labelInterval = 1;
    for (int i = 0; i < dates.length; i++) {
      if (i % labelInterval != 0 && i != dates.length - 1) continue;
      if (i != dates.length - 1 &&
          (dates.length - 1 - i) < labelInterval / 2) continue;
      final x = indexToX(i);
      String displayDate = dates[i];
      try {
        final parts = dates[i].split('-');
        if (parts.length >= 3) displayDate = '${parts[1]}-${parts[2]}';
      } catch (_) {}
      final tp = TextPainter(
        text: TextSpan(
            text: displayDate,
            style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, plotBottom + 8));
    }
  }

  void _drawGradientFill(Canvas canvas, Path linePath, double plotLeft,
      double plotRight, double plotBottom, double plotTop, Color lineColor) {
    final fillPath = Path.from(linePath);
    fillPath.lineTo(plotRight, plotBottom);
    fillPath.lineTo(plotLeft, plotBottom);
    fillPath.close();

    final gradient = ChartGradientPalette.fillGradient(lineColor);
    final fillPaint = Paint()
      ..shader = gradient.createShader(
          Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawGlowLine(Canvas canvas, Path path, Color color) {
    final glowPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(path, glowPaint);

    final midGlowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawPath(path, midGlowPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawHoverTooltip(
      Canvas canvas,
      double Function(int) indexToX,
      double plotLeft,
      double plotRight,
      double plotTop,
      double plotBottom,
      double Function(double) valueToY) {
    final x = indexToX(hoverIndex!);
    final hoverLinePaint = Paint()
      ..color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, plotTop), Offset(x, plotBottom), hoverLinePaint);

    final tooltipItems = <MapEntry<String, double>>[];
    for (final seriesId in selectedSeries) {
      final values = seriesValues[seriesId];
      if (values != null && hoverIndex! < values.length) {
        tooltipItems.add(MapEntry(seriesId, values[hoverIndex!]));
      }
    }

    if (tooltipItems.isEmpty) return;

    final dateTp = TextPainter(
      text: TextSpan(
          text: dates[hoverIndex!],
          style: const TextStyle(color: Colors.white70, fontSize: 10)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    dateTp.layout();

    final namePainters = <TextPainter>[];
    final scorePainters = <TextPainter>[];
    for (final item in tooltipItems) {
      final series = seriesList.firstWhere(
        (s) => s.id == item.key,
        orElse: () => ChartSeries(
            id: '', name: '', color: theme.colorScheme.primary, values: []),
      );
      final value = item.value;
      final isNeg = value < 0;
      final displayColor =
          hasNegative && isNeg ? ChartGradientPalette.negativeColor : series.color;
      final scoreText = value >= 0
          ? '+${value.toStringAsFixed(1)}'
          : value.toStringAsFixed(1);
      final scoreTp = TextPainter(
        text: TextSpan(
            text: scoreText,
            style: TextStyle(
                color: displayColor,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      scoreTp.layout();
      scorePainters.add(scoreTp);

      final nameTp = TextPainter(
        text: TextSpan(
            text: series.name,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );
      namePainters.add(nameTp);
    }

    final maxScoreWidth =
        scorePainters.fold(0.0, (max, tp) => tp.width > max ? tp.width : max);
    final tooltipW = (dateTp.width + maxScoreWidth + 60).clamp(140.0, 260.0);
    final nameMaxWidth = tooltipW - maxScoreWidth - 28;
    for (final nameTp in namePainters) {
      nameTp.layout(maxWidth: nameMaxWidth);
    }

    final tooltipH = 12.0 + tooltipItems.length * 20.0 + 8.0;
    double tooltipX = x - tooltipW / 2;
    double tooltipY = plotTop + 5;
    if (tooltipX < plotLeft) tooltipX = plotLeft;
    if (tooltipX + tooltipW > plotRight) tooltipX = plotRight - tooltipW;

    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
        tooltipRect, Paint()..color = Colors.black.withValues(alpha: 0.85));
    canvas.drawRRect(
        tooltipRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    canvas.save();
    canvas.translate(tooltipX + 8, tooltipY + 6);
    dateTp.paint(canvas, Offset.zero);
    canvas.restore();

    for (int i = 0; i < tooltipItems.length; i++) {
      final y = tooltipY + 22 + i * 20;
      canvas.save();
      canvas.translate(tooltipX + 8, y);
      namePainters[i].paint(canvas, Offset.zero);
      canvas.restore();

      canvas.save();
      canvas.translate(
          tooltipX + tooltipW - scorePainters[i].width - 8, y);
      scorePainters[i].paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumTrendPainter oldDelegate) {
    return oldDelegate.hoverIndex != hoverIndex ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.selectedSeries != selectedSeries ||
        oldDelegate.normalized != normalized ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.seriesValues != seriesValues;
  }
}
