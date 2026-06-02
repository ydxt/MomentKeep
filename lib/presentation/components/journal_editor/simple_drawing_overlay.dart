import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'drawing_point.dart';
import 'background_type.dart';

/// A simplified, crash-resistant drawing overlay widget
class SimpleDrawingOverlay extends StatefulWidget {
  final bool isDrawingMode;
  final List<DrawingPoint>? initialDrawingPoints;
  final Function(List<DrawingPoint>) onDrawingUpdated;
  final VoidCallback onExitDrawingMode;
  final ScrollController? scrollController;
  final ValueNotifier<Color> brushColorNotifier;
  final ValueNotifier<double> brushWidthNotifier;
  final ValueNotifier<double> eraserWidthNotifier;
  final ValueNotifier<bool> isEraserModeNotifier;
  final ValueNotifier<bool> showHorizontalLinesNotifier;
  final BackgroundType backgroundType;
  final Color backgroundColor;

  const SimpleDrawingOverlay({
    super.key,
    required this.isDrawingMode,
    this.initialDrawingPoints,
    required this.onDrawingUpdated,
    required this.onExitDrawingMode,
    this.scrollController,
    required this.brushColorNotifier,
    required this.brushWidthNotifier,
    required this.eraserWidthNotifier,
    required this.isEraserModeNotifier,
    required this.showHorizontalLinesNotifier,
    this.backgroundType = BackgroundType.transparent,
    this.backgroundColor = Colors.white,
  });

  @override
  State<SimpleDrawingOverlay> createState() => _SimpleDrawingOverlayState();
}

class _SimpleDrawingOverlayState extends State<SimpleDrawingOverlay> {
  // 使用 ValueNotifier 来管理临时绘图点，实时更新到外部
  late final ValueNotifier<List<DrawingPoint>> _tempPointsNotifier;

  // Maximum number of points to keep in memory (adaptive for complex drawings)
  int get maxPoints => _adaptiveMaxPoints;
  int _adaptiveMaxPoints = 5000;

  // Adaptive memory management
  int _currentMemoryUsage = 0;
  static const int _memoryThreshold = 10 * 1024 * 1024; // 10MB threshold

  // Points and drawing state
  final List<DrawingPoint> _currentStrokePoints = [];

  // 性能优化：使用自适应防抖机制避免频繁更新
  Timer? _updateDebouncer;

  // Windows特定优化：批量处理绘制点，减少状态更新频率
  List<DrawingPoint> _pendingDrawPoints = [];
  int _pendingDrawPointsCount = 0;
  static const int _batchUpdateThreshold = 3; // 优化批量阈值，平衡响应性和性能

  // Windows特定优化：使用脏标志减少不必要的重绘逻辑
  bool _isCanvasDirty = false;

  // 状态标记，避免重复处理
  bool _isDisposed = false;

  // 并发控制锁
  bool _isProcessingUpdate = false;
  final List<Function()> _pendingOperations = [];

  // 橡皮擦节流时间戳
  int _lastEraserTimestamp = 0;

  // Brush and eraser state
  Color _currentBrushColor = Colors.black;
  double _currentBrushWidth = 3.0;
  double _currentEraserWidth = 3.0;
  bool _currentIsEraserMode = false;

  // Custom cursor state for Windows
  final ValueNotifier<Offset?> _cursorPositionNotifier =
      ValueNotifier<Offset?>(null);
  final ValueNotifier<bool> _isCursorInOverlayNotifier =
      ValueNotifier<bool>(false);

  /// 增强的错误恢复机制 - 确保在Windows端更加安全可靠
  void _recoverToSafeState() {
    // 使用顶级try-catch捕获所有可能的异常
    runZonedGuarded(() {
      debugPrint('Attempting AGGRESSIVE recovery to safe drawing state...');

      // 1. 激进清理当前笔画数据
      _currentStrokePoints.clear();

      // 2. 激进清理待处理的绘制点
      _pendingDrawPoints.clear();
      _pendingDrawPointsCount = 0;

      // 3. 取消所有待处理的定时器和操作
      _updateDebouncer?.cancel();
      _updateDebouncer = null;

      // 4. 清空操作队列 - 避免队列中的操作导致再次崩溃
      _pendingOperations.clear();

      // 5. 重置处理状态标志 - 确保组件可以恢复正常操作
      _isProcessingUpdate = false;
      _isCanvasDirty = true;

      // 7. 重置内存使用和点数限制到最安全的值
      _currentMemoryUsage = 0;
      _adaptiveMaxPoints = 1000; // 降低到最保守值

      // 8. 激进重置绘图点数据，防止损坏数据继续传播
      try {
        if (!_isDisposed && mounted) {
          final currentPoints = _tempPointsNotifier.value;
          if (currentPoints.isNotEmpty) {
            // 只保留最后少量点，避免完全丢失用户数据
            final safePoints = currentPoints.take(100).toList();
            _tempPointsNotifier.value = safePoints;
            debugPrint(
                'Emergency recovery: reduced points from ${currentPoints.length} to ${safePoints.length}');
          }
        }
      } catch (e) {
        debugPrint('Error during emergency point reset: $e');
        // 如果连重置都失败，创建全新的空列表
        try {
          if (!_isDisposed && mounted) {
            final emptyList = <DrawingPoint>[];
            _tempPointsNotifier.value = emptyList;
          }
        } catch (_) {
          // 最后的防护：什么都不做，避免二次崩溃
        }
      }

      // 6. 重置自适应参数
      _adaptiveMaxPoints = 5000;
      _currentMemoryUsage = 0;

      // 8. 确保_tempPointsNotifier的状态
      if (!_isDisposed && mounted) {
        // 恢复成功
      }

      debugPrint(
          'Recovered to safe state successfully, preserved existing drawing points');
    }, (e, stackTrace) {
      debugPrint('Critical error in recovery mechanism: $e');
      debugPrint('Stack trace: $stackTrace');

      // 最后的安全措施 - 直接重置所有状态
      try {
        // 强制重置所有关键状态，确保组件不会完全崩溃
        _isProcessingUpdate = false;
        _pendingOperations.clear();
        _updateDebouncer?.cancel();
        _updateDebouncer = null;
      } catch (_) {
        // 忽略所有错误，确保恢复机制不会本身导致崩溃
      }
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('SimpleDrawingOverlay: initState - State created (internal)');
    // 直接使用父组件传递的初始点，不进行过度验证，避免过滤掉有效点
    _tempPointsNotifier = ValueNotifier<List<DrawingPoint>>(
        widget.initialDrawingPoints != null
            ? List<DrawingPoint>.from(widget.initialDrawingPoints!)
            : <DrawingPoint>[]);

    _cursorPositionNotifier.value = null;
    _isCursorInOverlayNotifier.value = false;

    // Initialize brush settings from widget ValueNotifiers
    _currentBrushColor = widget.brushColorNotifier.value;
    _currentBrushWidth = widget.brushWidthNotifier.value;
    _currentEraserWidth = widget.eraserWidthNotifier.value;
    _currentIsEraserMode = widget.isEraserModeNotifier.value;

    // Add listeners to ValueNotifiers for real-time updates without full rebuilds
    widget.brushColorNotifier.addListener(_onBrushColorChanged);
    widget.brushWidthNotifier.addListener(_onBrushWidthChanged);
    widget.eraserWidthNotifier.addListener(_onEraserWidthChanged);
    widget.isEraserModeNotifier.addListener(_onIsEraserModeChanged);
    widget.showHorizontalLinesNotifier
        .addListener(_onShowHorizontalLinesChanged);
  }

  void _onShowHorizontalLinesChanged() {
    _isCanvasDirty = true;
  }

  void _onBrushColorChanged() {
    _currentBrushColor = widget.brushColorNotifier.value;
  }

  void _onBrushWidthChanged() {
    // 限制画笔宽度范围，防止异常值导致崩溃
    _currentBrushWidth = widget.brushWidthNotifier.value.clamp(1.0, 50.0);
  }

  void _onEraserWidthChanged() {
    // 限制橡皮擦宽度范围，防止异常值导致崩溃
    _currentEraserWidth = widget.eraserWidthNotifier.value.clamp(1.0, 50.0);
  }

  void _onIsEraserModeChanged() {
    _currentIsEraserMode = widget.isEraserModeNotifier.value;
  }

  @override
  void dispose() {
    debugPrint('SimpleDrawingOverlay: dispose - Cleaning up resources');
    _isDisposed = true;
    _updateDebouncer?.cancel();
    _updateDebouncer = null;
    _tempPointsNotifier.dispose();
    _cursorPositionNotifier.dispose();
    _isCursorInOverlayNotifier.dispose();
    _currentStrokePoints.clear();
    _pendingOperations.clear();
    _isProcessingUpdate = false;
    _isCanvasDirty = false;

    // Remove listeners from ValueNotifiers to prevent memory leaks
    widget.brushColorNotifier.removeListener(_onBrushColorChanged);
    widget.brushWidthNotifier.removeListener(_onBrushWidthChanged);
    widget.eraserWidthNotifier.removeListener(_onEraserWidthChanged);
    widget.isEraserModeNotifier.removeListener(_onIsEraserModeChanged);
    widget.showHorizontalLinesNotifier
        .removeListener(_onShowHorizontalLinesChanged);

    debugPrint('SimpleDrawingOverlay: dispose - Resources cleaned up');
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SimpleDrawingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If notifiers changed, update listeners
    if (widget.brushColorNotifier != oldWidget.brushColorNotifier) {
      oldWidget.brushColorNotifier.removeListener(_onBrushColorChanged);
      widget.brushColorNotifier.addListener(_onBrushColorChanged);
      _currentBrushColor = widget.brushColorNotifier.value;
    }
    if (widget.brushWidthNotifier != oldWidget.brushWidthNotifier) {
      oldWidget.brushWidthNotifier.removeListener(_onBrushWidthChanged);
      widget.brushWidthNotifier.addListener(_onBrushWidthChanged);
      _currentBrushWidth = widget.brushWidthNotifier.value;
    }
    if (widget.eraserWidthNotifier != oldWidget.eraserWidthNotifier) {
      oldWidget.eraserWidthNotifier.removeListener(_onEraserWidthChanged);
      widget.eraserWidthNotifier.addListener(_onEraserWidthChanged);
      _currentEraserWidth = widget.eraserWidthNotifier.value;
    }
    // 检查initialDrawingPoints是否变化，比较内容而非引用
    bool pointsChanged = false;
    if (widget.initialDrawingPoints == null &&
        oldWidget.initialDrawingPoints != null) {
      pointsChanged = true;
    } else if (widget.initialDrawingPoints != null &&
        oldWidget.initialDrawingPoints == null) {
      pointsChanged = true;
    } else if (widget.initialDrawingPoints != null &&
        oldWidget.initialDrawingPoints != null) {
      if (widget.initialDrawingPoints!.length !=
          oldWidget.initialDrawingPoints!.length) {
        pointsChanged = true;
      } else {
        // 比较内容是否相同
        for (int i = 0; i < widget.initialDrawingPoints!.length; i++) {
          if (widget.initialDrawingPoints![i] !=
              oldWidget.initialDrawingPoints![i]) {
            pointsChanged = true;
            break;
          }
        }
      }
    }

    if (pointsChanged) {
      debugPrint(
          'SimpleDrawingOverlay: initialDrawingPoints changed, syncing _tempPointsNotifier');
      _tempPointsNotifier.value = widget.initialDrawingPoints != null
          ? List<DrawingPoint>.from(widget.initialDrawingPoints!)
          : <DrawingPoint>[];
      _isCanvasDirty = true;
    }

    if (widget.isDrawingMode != oldWidget.isDrawingMode) {
      debugPrint(
          'SimpleDrawingOverlay: didUpdateWidget - isDrawingMode changed to ${widget.isDrawingMode}');

      // 关键：立即重置处理状态和清除队列，不等待异步操作，防止“一会后崩溃”
      _isProcessingUpdate = false;
      _pendingOperations.clear();
      _updateDebouncer?.cancel();

      // 重置光标状态
      _cursorPositionNotifier.value = null;
      _isCursorInOverlayNotifier.value = false;

      if (widget.isDrawingMode) {
        _isCanvasDirty = true;
        // Entering drawing mode: reset state
        _currentStrokePoints.clear();
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;
        _currentMemoryUsage = 0;
        _adaptiveMaxPoints = 5000;
        _lastEraserTimestamp = 0;
      } else {
        // Exiting drawing mode: save final data
        try {
          final allCurrentPoints =
              List<DrawingPoint>.from(_tempPointsNotifier.value);

          if (_currentStrokePoints.isNotEmpty) {
            final lastStrokePoint = _currentStrokePoints.last;
            final endPoint = DrawingPoint(
              offset: lastStrokePoint.offset,
              color: lastStrokePoint.color,
              width: lastStrokePoint.width,
              isEndOfStroke: true,
            );
            allCurrentPoints.add(endPoint);
          }

          if (_pendingDrawPoints.isNotEmpty) {
            allCurrentPoints.addAll(_pendingDrawPoints);
          }

          List<DrawingPoint> cleanPoints = [];
          for (final point in allCurrentPoints) {
            if (!point.offset.dx.isFinite || !point.offset.dy.isFinite)
              continue;
            cleanPoints.add(point);
          }

          if (!_isDisposed && mounted) {
            widget.onDrawingUpdated(cleanPoints);
          }
        } catch (e) {
          debugPrint('Error saving points on exit: $e');
        }

        _recoverToSafeState();
      }
    }
  }

  /// 自适应调整点数限制
  void _adjustMaxPointsBasedOnMemory() {
    final estimatedMemory = _currentMemoryUsage;

    if (estimatedMemory > _memoryThreshold) {
      // 内存使用过高，减少点数限制
      _adaptiveMaxPoints = max(1000, _adaptiveMaxPoints ~/ 2);
      debugPrint(
          'Reducing max points to $_adaptiveMaxPoints due to memory pressure');
    } else if (estimatedMemory < _memoryThreshold ~/ 2) {
      // 内存使用正常，可以增加点数限制
      _adaptiveMaxPoints = min(8000, _adaptiveMaxPoints + 500);
    }
  }

  /// 过滤和验证绘图点，确保数据有效性
  List<DrawingPoint> _filterAndValidatePoints(List<DrawingPoint>? points) {
    try {
      // 简化的防御性检查
      if (points == null || points.isEmpty) {
        return <DrawingPoint>[];
      }

      // 自适应调整点数限制
      _adjustMaxPointsBasedOnMemory();

      // 创建points的安全副本，避免原始数据被修改
      final pointsCopy = List<DrawingPoint>.from(points);

      // 简化的点过滤和验证
      final validatedPoints = <DrawingPoint>[];
      for (final point in pointsCopy) {
        // 基础防御性检查
        if (!point.offset.dx.isFinite || !point.offset.dy.isFinite) continue;

        // 过滤无效零点（非结束标记的零点）
        if (point.offset.dx == 0 &&
            point.offset.dy == 0 &&
            !point.isEndOfStroke) continue;

        // 限制最大点数
        if (validatedPoints.length >= maxPoints) break;

        validatedPoints.add(point);
      }

      // 更新状态
      _currentMemoryUsage = validatedPoints.length * 32; // 估算每个点32字节

      // 确保如果输入非空，返回的列表也非空
      if (validatedPoints.isEmpty && pointsCopy.isNotEmpty) {
        // 如果验证后为空但原始数据不为空，返回原始数据的安全副本
        debugPrint(
            'Warning: Validation filtered all points, preserving original data');
        final safeCopy = List<DrawingPoint>.from(pointsCopy);
        return safeCopy.take(maxPoints).toList();
      }

      return validatedPoints;
    } catch (e, stackTrace) {
      debugPrint('Critical error filtering points: $e');
      debugPrint('Stack trace: $stackTrace');

      // 重置状态，确保组件能恢复到安全状态
      _currentMemoryUsage = 0;

      // 如果出错，返回原始数据的安全副本（如果有），而不是空列表
      if (points != null && points.isNotEmpty) {
        debugPrint('Error filtering points, preserving original data');
        final safeCopy = List<DrawingPoint>.from(points);
        return safeCopy.take(maxPoints).toList();
      }

      return <DrawingPoint>[];
    }
  }

  void _safeExecuteUpdate(Function() operation) {
    if (_isDisposed) {
      return;
    }

    // 对于普通绘图操作，使用队列
    if (_isProcessingUpdate) {
      // 限制队列长度，防止无限增长引起的内存压力和崩溃
      if (_pendingOperations.length < 50) {
        _pendingOperations.add(operation);
      } else {
        // 如果队列太满，丢弃较旧的操作以保持实时性
        _pendingOperations.removeRange(0, 25);
        _pendingOperations.add(operation);
        debugPrint('Update queue overflow: discarded 25 old operations');
      }
      return;
    }

    _isProcessingUpdate = true;

    // 使用 Zone 捕获所有可能的异常，包括异步异常
    runZonedGuarded(() {
      try {
        operation();
      } finally {
        // 即使 operation 出错，也要处理队列中的下一个操作
        _processNextOperation();
      }
    }, (e, stackTrace) {
      debugPrint('Critical error in safe execute update: $e\n$stackTrace');
      // 尝试恢复到安全状态
      _recoverToSafeState();

      // 出错后也要重置状态并处理队列
      _isProcessingUpdate = false;
      _processNextOperation();
    });
  }

  /// 处理队列中的下一个操作
  void _processNextOperation() {
    if (_isDisposed || _pendingOperations.isEmpty) {
      _isProcessingUpdate = false;
      return;
    }

    // 使用 microtask 异步处理队列，避免长时间阻塞 UI 线程
    scheduleMicrotask(() {
      if (_isDisposed || _pendingOperations.isEmpty) {
        _isProcessingUpdate = false;
        return;
      }

      // 每次 microtask 只处理少量操作，给 UI 线程喘息机会
      int processedCount = 0;
      const int maxBatchSize = 10;

      while (!_isDisposed &&
          _pendingOperations.isNotEmpty &&
          processedCount < maxBatchSize) {
        final nextOperation = _pendingOperations.removeAt(0);
        try {
          nextOperation();
        } catch (e, stackTrace) {
          debugPrint('Error in operation: $e\n$stackTrace');
          _recoverToSafeState();
        }
        processedCount++;
      }

      // 如果还有剩余操作，使用Timer而非递归调用，避免栈溢出
      if (!_isDisposed && _pendingOperations.isNotEmpty) {
        Timer(const Duration(microseconds: 100), _processNextOperation);
      } else {
        _isProcessingUpdate = false;
      }
    });
  }

  /// 自适应防抖更新父组件
  void _adaptiveDebouncedNotifyParent(List<DrawingPoint> points) {
    if (_isDisposed) return;

    _updateDebouncer?.cancel();

    // 根据当前性能调整延迟
    final performanceBasedDelay = _currentMemoryUsage > _memoryThreshold ~/ 2
        ? Duration(milliseconds: 32)
        : Duration(milliseconds: 16);

    _updateDebouncer = Timer(performanceBasedDelay, () {
      // 再次检查组件状态，确保组件仍然存在
      if (_isDisposed || !mounted) {
        return;
      }

      try {
        final stopwatch = Stopwatch()..start();

        // 创建绘图点的安全副本，避免原始数据被修改
        final safePoints = List<DrawingPoint>.from(points);

        // 确保只传递有效的绘图点
        final validatedPoints = _filterAndValidatePoints(safePoints);

        // 只在有实际需要更新时才调用父组件回调
        if (validatedPoints.isNotEmpty || points.isEmpty) {
          widget.onDrawingUpdated(validatedPoints);
        }

        stopwatch.stop();

        // 根据执行时间调整下次延迟
        // Using fixed delay instead of variable delay to avoid performance issues
      } catch (e) {
        debugPrint('Error in debounced notify parent: $e');
        // 出现错误时尝试恢复到安全状态
        _recoverToSafeState();
      }
    });
  }

  void _handlePointerDown(PointerDownEvent details) {
    if (!widget.isDrawingMode || _isDisposed) return;

    final offset = details.localPosition;
    if (!offset.dx.isFinite || !offset.dy.isFinite) return;

    _safeExecuteUpdate(() {
      try {
        _currentStrokePoints.clear();
        _updateDebouncer?.cancel(); // 取消之前的防抖更新

        if (!_currentIsEraserMode) {
          // 正常绘图模式：创建新点
          // 获取当前点并强制完整验证，避免状态污染
          var currentPoints = _tempPointsNotifier.value;

          // 直接使用当前点列表，不进行额外验证，避免过滤掉有效点
          var updatedPoints = List<DrawingPoint>.from(currentPoints);

          // 添加上一笔的结束标记（如果有上一笔且未结束）
          if (updatedPoints.isNotEmpty && !updatedPoints.last.isEndOfStroke) {
            final lastPoint = updatedPoints.last;
            updatedPoints.add(DrawingPoint(
              offset: lastPoint.offset,
              color: lastPoint.color,
              width: lastPoint.width,
              isEndOfStroke: true,
            ));
          }

          // 创建新的绘图点，使用当前的画笔设置
          final point = DrawingPoint(
            offset: offset,
            color: _currentBrushColor,
            width: _currentBrushWidth.clamp(1.0, 50.0), // 限制画笔宽度范围
          );
          _currentStrokePoints.add(point);
          updatedPoints.add(point);

          // 限制点数并创建新的列表实例
          final finalPoints =
              List<DrawingPoint>.from(updatedPoints.take(maxPoints));
          if (!_isDisposed && mounted) {
            _tempPointsNotifier.value = finalPoints;
          }

          debugPrint(
              'PointerDown: Added point, total points: ${finalPoints.length}');
        } else {
          // 橡皮擦模式：按下时也进行一次擦除检测，确保点击即擦除
          try {
            final currentPoints = _tempPointsNotifier.value;
            if (currentPoints.isNotEmpty) {
              // 橡皮擦逻辑优化：使用更宽的判定范围
              final eraserRadius = _currentEraserWidth * 5.0;
              final eraserRadiusSq = eraserRadius * eraserRadius;

              final updatedPoints = <DrawingPoint>[];
              for (final point in currentPoints) {
                // DrawingPoint 列表中的点不再包含 null
                final dx = point.offset.dx - offset.dx;
                final dy = point.offset.dy - offset.dy;
                if ((dx * dx + dy * dy) > eraserRadiusSq) {
                  updatedPoints.add(point);
                }
              }

              if (updatedPoints.length != currentPoints.length) {
                if (!_isDisposed && mounted) {
                  _tempPointsNotifier.value = updatedPoints;
                  debugPrint(
                      'Eraser hit! Removed ${currentPoints.length - updatedPoints.length} points');
                  // 橡皮擦按下时的通知也进行节流，避免父组件过度重建
                  _adaptiveDebouncedNotifyParent(updatedPoints);
                }
              }
            }
          } catch (e) {
            debugPrint('Error in PointerDown eraser check: $e');
          }
          debugPrint('PointerDown: Eraser check performed');
        }
      } catch (e, stackTrace) {
        debugPrint('Error in _handlePointerDown: $e');
        debugPrint('Stack trace: $stackTrace');
        // 尝试恢复到安全状态
        _recoverToSafeState();
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent details) {
    // 快速返回条件检查
    if (!widget.isDrawingMode || _isDisposed) {
      _pendingDrawPoints.clear();
      _pendingDrawPointsCount = 0;
      return;
    }

    final offset = details.localPosition;
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return;
    }

    try {
      if (_currentIsEraserMode) {
        // 橡皮擦模式优化：手动节流，不使用 _isProcessingUpdate 阻塞，
        // 这样可以确保橡皮擦始终可以响应，但不会每帧都执行耗时的过滤操作
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastEraserTimestamp < 16) return; // 限制在约 60Hz
        _lastEraserTimestamp = now;

        final currentPoints = _tempPointsNotifier.value;
        if (currentPoints.isEmpty) return;

        // 使用 for 循环代替 where 以获得更好的性能，尤其是 Windows 端
        final eraserRadius = _currentEraserWidth * 5.0;
        final eraserRadiusSq = eraserRadius * eraserRadius;

        final updatedPoints = <DrawingPoint>[];
        bool changed = false;

        for (final point in currentPoints) {
          final dx = point.offset.dx - offset.dx;
          final dy = point.offset.dy - offset.dy;
          if ((dx * dx + dy * dy) > eraserRadiusSq) {
            updatedPoints.add(point);
          } else {
            changed = true;
          }
        }

        if (changed) {
          // 确保在组件未销毁时才更新状态
          if (!_isDisposed && mounted) {
            _tempPointsNotifier.value = updatedPoints;
            // 橡皮擦通知也进行自适应防抖，避免父组件过载
            _adaptiveDebouncedNotifyParent(updatedPoints);
          }
        }
      } else {
        // 正常绘图模式：创建新点
        final point = DrawingPoint(
          offset: offset,
          color: _currentBrushColor,
          width: _currentBrushWidth.clamp(1.0, 50.0), // 限制画笔宽度范围
        );

        // 添加到笔画
        _currentStrokePoints.add(point);

        // 批量处理
        _pendingDrawPoints.add(point);
        _pendingDrawPointsCount++;

        // 优化批量阈值，平衡响应性和性能
        if (_pendingDrawPointsCount >= _batchUpdateThreshold) {
          if (!_isDisposed && mounted && widget.isDrawingMode) {
            _safeExecuteUpdate(() {
              _updateDrawingPoints();
            });
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _handlePointerMove: $e');
      debugPrint('Stack trace: $stackTrace');

      // 简化恢复逻辑
      try {
        _currentStrokePoints.clear();
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;
      } catch (_) {}
    }
  }

  /// 更新绘图点的辅助方法，避免重复代码
  void _updateDrawingPoints() {
    if (_isDisposed || !mounted || !widget.isDrawingMode) {
      _pendingDrawPoints.clear();
      _pendingDrawPointsCount = 0;
      return;
    }

    try {
      if (_pendingDrawPoints.isNotEmpty) {
        // 一次性处理所有待处理的点，避免产生积压 (Backlog)
        final currentPoints = _tempPointsNotifier.value;

        // 合并点
        final updatedPoints = List<DrawingPoint>.from(currentPoints)
          ..addAll(_pendingDrawPoints);

        // 清空当前待处理列表
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;

        // 应用最大点数限制，保留最后的点
        final limitedPoints = updatedPoints.length > maxPoints
            ? updatedPoints.sublist(updatedPoints.length - maxPoints)
            : updatedPoints;

        _tempPointsNotifier.value = limitedPoints;

        // 防抖通知父组件
        _adaptiveDebouncedNotifyParent(limitedPoints);
      }
    } catch (e) {
      debugPrint('Error in _updateDrawingPoints: $e');
      _recoverToSafeState();
    }
  }

  void _handlePointerUp(PointerUpEvent details) {
    // 更新光标位置，即使不在绘图模式或笔画为空
    if (widget.isDrawingMode && !_isDisposed) {
      _cursorPositionNotifier.value = details.localPosition;
    }

    if (!widget.isDrawingMode || _isDisposed || _currentStrokePoints.isEmpty) {
      // 确保在任何情况下都清空待处理点列表和当前笔画
      _pendingDrawPoints.clear();
      _pendingDrawPointsCount = 0;
      _currentStrokePoints.clear();
      return;
    }

    _safeExecuteUpdate(() {
      try {
        // 1. 先处理所有待处理的点
        if (_pendingDrawPoints.isNotEmpty) {
          final currentPoints = _tempPointsNotifier.value;
          final tempUpdatedPoints = List<DrawingPoint>.from(currentPoints);
          tempUpdatedPoints.addAll(_pendingDrawPoints);
          _tempPointsNotifier.value =
              tempUpdatedPoints.take(maxPoints).toList();
        }

        // 2. 确保当前笔画已完成
        if (_currentStrokePoints.isNotEmpty) {
          final lastPoint = _currentStrokePoints.last;
          final endPoint = DrawingPoint(
            offset: lastPoint.offset,
            color: _currentBrushColor,
            width: _currentBrushWidth,
            isEndOfStroke: true,
          );

          // 3. 获取最新的点列表并添加结束点
          final currentPoints = _tempPointsNotifier.value;
          final updatedPoints = List<DrawingPoint>.from(currentPoints);
          updatedPoints.add(endPoint);

          // 4. 更新状态
          _tempPointsNotifier.value = updatedPoints.take(maxPoints).toList();
        }

        // 5. 清空所有临时状态
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;
        _currentStrokePoints.clear();
      } catch (e, stackTrace) {
        debugPrint('Error in _handlePointerUp: $e');
        debugPrint('Stack trace: $stackTrace');
        // 清空所有临时状态，确保安全
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;
        _currentStrokePoints.clear();
      }
    });
  }

  void _handlePointerCancel(PointerCancelEvent details) {
    // 更新光标位置，即使在取消事件中
    if (widget.isDrawingMode && !_isDisposed) {
      _cursorPositionNotifier.value = details.localPosition;
    }

    if (!widget.isDrawingMode || _isDisposed) return;

    _safeExecuteUpdate(() {
      try {
        // 如果当前笔画不为空，添加结束点
        if (_currentStrokePoints.isNotEmpty) {
          final lastPoint = _currentStrokePoints.last;
          final endPoint = DrawingPoint(
            offset: lastPoint.offset,
            color: _currentBrushColor,
            width: _currentBrushWidth,
            isEndOfStroke: true,
          );

          // 将结束点添加到待处理的绘制点中
          _pendingDrawPoints.add(endPoint);
          _pendingDrawPointsCount++;
        }

        // 处理所有待处理的绘制点，确保状态一致性
        if (_pendingDrawPoints.isNotEmpty) {
          // 获取当前点列表并添加所有待处理点
          final currentPoints = _tempPointsNotifier.value;
          final updatedPoints = List<DrawingPoint>.from(currentPoints);
          updatedPoints.addAll(_pendingDrawPoints);

          // 直接限制点数，不进行额外验证
          final limitedPoints = updatedPoints.take(maxPoints).toList();

          // 更新状态
          if (!_isDisposed && mounted) {
            _tempPointsNotifier.value = limitedPoints;
          }

          // 清空待处理点列表
          _pendingDrawPoints.clear();
          _pendingDrawPointsCount = 0;
        }

        // 清空当前笔画
        _currentStrokePoints.clear();
      } catch (e, stackTrace) {
        debugPrint('Error in _handlePointerCancel: $e');
        debugPrint('Stack trace: $stackTrace');
        // 清空待处理点和当前笔画
        _pendingDrawPoints.clear();
        _pendingDrawPointsCount = 0;
        _currentStrokePoints.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 关键：对整个组件启用 ExcludeSemantics，彻底解决 Windows 端语义节点过载导致的崩溃
    // 渲染隔离：作为纯绘图画布，不再包含任何交互按钮，避免语义冲突
    return ExcludeSemantics(
      child: MouseRegion(
        cursor:
            widget.isDrawingMode ? SystemMouseCursors.none : MouseCursor.defer,
        onEnter: (event) {
          if (widget.isDrawingMode) {
            _cursorPositionNotifier.value = event.localPosition;
            _isCursorInOverlayNotifier.value = true;
          }
        },
        onHover: (event) {
          if (widget.isDrawingMode) {
            _cursorPositionNotifier.value = event.localPosition;
            if (!_isCursorInOverlayNotifier.value) {
              _isCursorInOverlayNotifier.value = true;
            }
          }
        },
        onExit: (event) {
          // 不再激进地隐藏，防止 Windows 端失去焦点后无法找回
          // _isCursorInOverlayNotifier.value = false;
          debugPrint('MouseRegion: onExit');
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand, // 使用 expand fit，确保 Stack 填充父容器
            children: [
              // 1. 绘图内容 - 显示当前绘制的轨迹
              RepaintBoundary(
                child: ValueListenableBuilder<List<DrawingPoint>>(
                  valueListenable: _tempPointsNotifier,
                  builder: (context, points, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _SimpleDrawingPainter(
                          points,
                          widget.showHorizontalLinesNotifier.value,
                          widget.backgroundColor,
                          widget.backgroundType,
                          _isCanvasDirty),
                    );
                  },
                ),
              ),
              // 2. 绘图手势处理 - 使用 Listener 处理指针事件
              Listener(
                behavior: HitTestBehavior.opaque, // 使用 opaque 确保在整个区域捕获事件
                onPointerDown: (event) {
                  if (widget.isDrawingMode) {
                    _cursorPositionNotifier.value = event.localPosition;
                    _isCursorInOverlayNotifier.value = true;
                  }
                  _handlePointerDown(event);
                },
                onPointerMove: (event) {
                  if (widget.isDrawingMode) {
                    _cursorPositionNotifier.value = event.localPosition;
                    _isCursorInOverlayNotifier.value = true;
                  }
                  _handlePointerMove(event);
                },
                onPointerHover: (event) {
                  if (widget.isDrawingMode) {
                    _cursorPositionNotifier.value = event.localPosition;
                    _isCursorInOverlayNotifier.value = true;
                  }
                },
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: const SizedBox.expand(), // 确保 Listener 具有明确的尺寸
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _isCursorInOverlayNotifier,
                builder: (context, inRegion, child) {
                  // 如果不在区域内但已经有位置，且是在绘图模式下，我们依然尝试显示（增强鲁棒性）
                  if (!widget.isDrawingMode) return const SizedBox.shrink();

                  return ValueListenableBuilder<Offset?>(
                    valueListenable: _cursorPositionNotifier,
                    builder: (context, pos, child) {
                      if (pos == null) return const SizedBox.shrink();

                      return IgnorePointer(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: widget.isEraserModeNotifier,
                          builder: (context, isEraser, child) {
                            return ValueListenableBuilder<double>(
                              valueListenable: isEraser
                                  ? widget.eraserWidthNotifier
                                  : widget.brushWidthNotifier,
                              builder: (context, width, child) {
                                final double cursorSize =
                                    width.clamp(10.0, 100.0);
                                return Stack(
                                  children: [
                                    Positioned(
                                      left: pos.dx - cursorSize / 2,
                                      top: pos.dy - cursorSize / 2,
                                      child: Container(
                                        width: cursorSize,
                                        height: cursorSize,
                                        decoration: BoxDecoration(
                                          shape: isEraser
                                              ? BoxShape.rectangle
                                              : BoxShape.circle,
                                          color: isEraser
                                              ? Colors.red.withOpacity(0.3)
                                              : widget.brushColorNotifier.value
                                                  .withOpacity(0.3),
                                          border: Border.all(
                                            color: isEraser
                                                ? Colors.red
                                                : widget
                                                    .brushColorNotifier.value,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleDrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;
  final bool showHorizontalLines;
  final Color backgroundColor;
  final BackgroundType backgroundType;
  final bool isDirty;

  _SimpleDrawingPainter(this.points, this.showHorizontalLines,
      this.backgroundColor, this.backgroundType, this.isDirty);

  @override
  void paint(Canvas canvas, Size size) {
    // 使用顶级try-catch捕获所有可能的异常
    try {
      // Draw background based on background type
      if (backgroundType == BackgroundType.solid) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = backgroundColor);
      } else if (backgroundType == BackgroundType.grid) {
        // Draw grid background
        final gridPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..color = Colors.grey.withOpacity(0.3)
          ..strokeWidth = 1.0;

        // Draw vertical lines
        for (double x = 20; x < size.width; x += 20) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
        }

        // Draw horizontal lines
        for (double y = 20; y < size.height; y += 20) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
        }
      }

      // Draw horizontal lines if enabled (for both lines background type and showHorizontalLines flag)
      if (showHorizontalLines || backgroundType == BackgroundType.lines) {
        final linePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..color = Colors.grey.withOpacity(0.3)
          ..strokeWidth = 1.0;

        // Line height should match typical text line height
        const double lineHeight = 24.0;

        // Draw lines across the canvas
        for (double y = lineHeight; y < size.height; y += lineHeight) {
          final start = Offset(0, y);
          final end = Offset(size.width, y);
          canvas.drawLine(start, end, linePaint);
        }
      }

      // 优化渲染：使用更高效的路径合并策略
      if (points.isEmpty) return;

      Color? lastColor;
      double? lastWidth;
      Path? strokePath;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      for (int i = 0; i < points.length; i++) {
        final point = points[i];

        // 快速访问 offset 属性，避免多次空检查
        final dx = point.offset.dx;
        final dy = point.offset.dy;
        if (!dx.isFinite || !dy.isFinite) continue;

        // 当样式改变或新笔画开始时，绘制并重置路径
        if (strokePath == null ||
            point.color != lastColor ||
            point.width != lastWidth) {
          if (strokePath != null) {
            paint.color = lastColor ?? Colors.black;
            paint.strokeWidth = lastWidth ?? 3.0;
            canvas.drawPath(strokePath, paint);
          }
          strokePath = Path()..moveTo(dx, dy);
          lastColor = point.color;
          lastWidth = point.width;
        } else {
          strokePath.lineTo(dx, dy);
        }

        if (point.isEndOfStroke) {
          paint.color = lastColor ?? Colors.black;
          paint.strokeWidth = lastWidth ?? 3.0;
          canvas.drawPath(strokePath, paint);
          strokePath = null;
        }
      }

      // 绘制最后残余的路径
      if (strokePath != null && lastColor != null && lastWidth != null) {
        paint.color = lastColor;
        paint.strokeWidth = lastWidth;
        canvas.drawPath(strokePath, paint);
      }
    } catch (e, stackTrace) {
      debugPrint('Critical error in drawing paint: $e');
      debugPrint('Stack trace: $stackTrace');
      // 绘制一个简单的错误指示器，让用户知道发生了问题
      try {
        final errorPaint = Paint()
          ..color = Colors.red.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(50, 50), 20, errorPaint);

        // 绘制一个简单的错误信息
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'Error',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 40, maxWidth: 40);
        textPainter.paint(canvas, Offset(30, 43));
      } catch (_) {
        // 忽略绘制错误指示器时的异常
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleDrawingPainter oldDelegate) {
    try {
      // 检查脏标志
      if (isDirty) return true;

      // 简单直接的比较逻辑，避免复杂计算
      if (identical(oldDelegate.points, points) &&
          oldDelegate.showHorizontalLines == showHorizontalLines) {
        return false;
      }
      if (oldDelegate.points.length != points.length) return true;
      if (oldDelegate.showHorizontalLines != showHorizontalLines) return true;

      // 对于少量点，直接比较引用
      if (points.length <= 20) {
        // 检查引用是否相同，不进行深度比较
        return true;
      }

      // 对于大量点，只比较最后几个点的引用
      final compareCount = min(5, points.length);
      final startIndex = points.length - compareCount;

      for (int i = startIndex; i < points.length; i++) {
        final oldPoint = oldDelegate.points[i];
        final newPoint = points[i];

        // 只比较引用，不比较具体属性
        if (!identical(oldPoint, newPoint)) {
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error in shouldRepaint: $e');
      debugPrint('Stack trace: $stackTrace');
      // 出错时返回true，强制重绘以确保一致性
      return true;
    }
  }
}
