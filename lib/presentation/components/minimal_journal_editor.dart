import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/services/storage_service.dart';

import 'package:moment_keep/core/theme/app_theme.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/checkbox_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/custom_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/audio_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/video_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/image_embed_builder.dart';

import 'package:moment_keep/presentation/components/journal_editor/embed_builders/file_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/formula_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/code_block_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/unknown_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/embed_builders/drawing_embed_builder.dart';
import 'package:moment_keep/presentation/components/journal_editor/simple_drawing_overlay.dart';
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';
import 'package:moment_keep/presentation/components/journal_editor/background_type.dart';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:moment_keep/presentation/components/journal_editor/video_width_manager.dart';

/// 颜色扩展方法，用于将 Color 转换为十六进制字符串
extension ColorExtension on Color {
  /// 将 Color 转换为十六进制字符串，格式为 #RRGGBB
  String toHex() {
    return '#${value.toRadixString(16).substring(2).toUpperCase()}';
  }
}

/// Painter for drawing horizontal lines as background
class _HorizontalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = AppTheme.mediumGray.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // 假设每行文字高度为24.0，绘制横线
    const double lineHeight = 24.0;

    // 绘制横线，每条线对应一行文字的底部
    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // 横线样式固定，不需要重新绘制
  }
}

/// SafeRenderWidget - 增强图层隔离的安全渲染组件
/// 当子组件崩溃时，显示fallback内容，确保一个图层的错误不会影响另一个图层
class SafeRenderWidget extends StatelessWidget {
  final Widget child;
  final Widget fallback;

  const SafeRenderWidget({
    super.key,
    required this.child,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // 移除全局 ErrorWidget.builder 的副作用，改用更加安全的方式
    return child;
  }
}

/// Recording result model
class RecordingResult {
  final bool save;
  final String fileName;

  RecordingResult(this.save, this.fileName);
}

/// Custom painter for drawing smooth waveform
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color backgroundColor;
  final Color waveformColor;
  final Color baselineColor;

  WaveformPainter({
    required this.waveformData,
    required this.backgroundColor,
    required this.waveformColor,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Calculate center line (baseline)
    final centerY = size.height / 2;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      baselinePaint,
    );

    if (waveformData.isEmpty) return;

    // Prepare waveform paint
    final waveformPaint = Paint()
      ..color = waveformColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Calculate points for the waveform
    final points = <Offset>[];
    final stepX = size.width / (waveformData.length - 1);

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * stepX;
      // Convert normalized amplitude (0-1) to wave height around center
      // Map 0.1 (silence) to near center, 1.0 to full height
      final normalizedValue = waveformData[i];
      final waveHeight = (normalizedValue - 0.1) / 0.9; // Normalize from 0-1
      final y = centerY -
          (waveHeight * centerY * 0.8); // 80% of height for max amplitude
      points.add(Offset(x, y));
    }

    // Draw the waveform curve
    if (points.length > 1) {
      canvas.drawPoints(PointMode.polygon, points, waveformPaint);
    }

    // Optionally fill the area under the waveform
    if (points.length > 1) {
      final fillPaint = Paint()
        ..color = waveformColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final fillPath = Path()..moveTo(0, centerY);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(size.width, centerY);
      fillPath.close();

      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData;
  }
}

/// Audio recording dialog with waveform display
class AudioRecordingDialog extends StatefulWidget {
  final AudioRecorder recorder;
  final String tempPath;
  final String fileName;

  const AudioRecordingDialog({
    super.key,
    required this.recorder,
    required this.tempPath,
    required this.fileName,
  });

  @override
  State<AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<AudioRecordingDialog> {
  bool _isPaused = false;
  bool _isSaving = false;
  int _duration = 0;
  Timer? _timer;
  Timer? _waveformTimer;
  List<double> _waveformData = []; // Dynamic list instead of fixed length
  late StreamSubscription<Amplitude>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startAmplitudeSubscription();

    // Initialize waveform data with default values to prevent empty display
    _waveformData = List.generate(100, (index) => 0.1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveformTimer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration++;
      });
    });
  }

  void _startAmplitudeSubscription() {
    _amplitudeSubscription = widget.recorder
        .onAmplitudeChanged(const Duration(
            milliseconds: 50)) // Faster update for smoother waveform
        .listen((amplitude) {
      // Debug log to see actual amplitude values
      debugPrint('Raw amplitude: ${amplitude.current}, Max: ${amplitude.max}');

      setState(() {
        // Handle negative dB values (convert to positive amplitude)
        // dB values are typically negative, with 0 being the maximum

        // Convert dB to positive value (closer to 0 = louder sound)
        // Map the range from -100dB (silence) to 0dB (max volume)
        double positiveAmplitude = (amplitude.current + 100) / 100;

        // Normalize to 0-1 range
        double normalizedValue = positiveAmplitude.clamp(0.0, 1.0);

        // For a more natural wave appearance, we want to show both positive and negative deviations
        // from the baseline. We'll use a simple approach to create a wave-like pattern.

        // Update waveform data - keep using the normalized value but the WaveformPainter will
        // create the wave effect by mapping it around a center line
        _waveformData.add(normalizedValue);
        if (_waveformData.length > 100) {
          // More data points for smoother wave
          _waveformData.removeAt(0);
        }
      });
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await widget.recorder.resume();
      _startAmplitudeSubscription();
    } else {
      await widget.recorder.pause();
      _amplitudeSubscription?.cancel();
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _saveRecording() async {
    setState(() {
      _isSaving = true;
    });
    await widget.recorder.stop();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();

    Navigator.pop(context, RecordingResult(true, widget.fileName));
  }

  Future<void> _cancelRecording() async {
    await widget.recorder.stop();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();

    Navigator.pop(context, RecordingResult(false, widget.fileName));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('录音中'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recording timer
            Text(
              _formatDuration(_duration),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Waveform display
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: CustomPaint(
                painter: WaveformPainter(
                  waveformData: _waveformData,
                  backgroundColor: Colors.grey[100]!,
                  waveformColor: Colors.blue.withOpacity(0.8),
                  baselineColor: Colors.grey[400]!,
                ),
                size: const Size(double.infinity, 120),
              ),
            ),
            const SizedBox(height: 20),

            // Status text
            Text(
              _isPaused ? '已暂停' : '录音中...',
              style: TextStyle(
                color: _isPaused ? Colors.orange : Colors.green,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('取消'),
        ),

        // Pause/Resume button
        TextButton(
          onPressed: _togglePause,
          child: Text(_isPaused ? '继续' : '暂停'),
        ),

        // Save button
        TextButton(
          onPressed: _isSaving ? null : _saveRecording,
          child:
              _isSaving ? const CircularProgressIndicator() : const Text('保存'),
        ),
      ],
    );
  }
}

/// 极简日记编辑器组件
class MinimalJournalEditor extends StatefulWidget {
  /// 日记实体
  final Journal? journal;

  /// 分类信息
  final Category category;

  /// 保存回调
  final Function(Journal) onSave;

  /// 取消回调
  final Function() onCancel;

  /// 构造函数
  const MinimalJournalEditor({
    super.key,
    this.journal,
    required this.category,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<MinimalJournalEditor> createState() => _MinimalJournalEditorState();
}

class _MinimalJournalEditorState extends State<MinimalJournalEditor> {
  /// 标题控制器
  late TextEditingController _titleController;

  /// Flag to prevent auto-insertion loop when deleting a checkbox
  bool _isDeletingCheckbox = false;

  // 防止复选框处理的无限循环
  bool _isHandlingCheckbox = false;

  /// 标签列表
  late List<String> _tags;

  /// 分类ID
  late String _categoryId;

  /// Quill 控制器
  late flutter_quill.QuillController _controller;

  /// Focus node for QuillEditor to manage focus manually
  late FocusNode _quillFocusNode;

  /// Focus Attachment to properly attach the focus node to the widget tree
  late FocusAttachment _focusAttachment;

  /// Main scroll controller for the entire page (text + drawing)
  final ScrollController _pageScrollController = ScrollController();

  /// Audio Recorder
  final AudioRecorder _audioRecorder = AudioRecorder();

  /// Drawing mode state
  bool _isDrawingMode = false;

  /// Drawing points with ValueNotifier for better performance
  /// This allows us to update drawing points without calling setState
  final ValueNotifier<List<DrawingPoint>> _drawingPointsNotifier =
      ValueNotifier<List<DrawingPoint>>([]);

  /// Brush settings for drawing mode - Using ValueNotifier for real-time updates without full rebuilds
  late final ValueNotifier<Color> _brushColorNotifier;
  late final ValueNotifier<double> _brushWidthNotifier;
  late final ValueNotifier<double> _eraserWidthNotifier;
  late final ValueNotifier<bool> _isEraserModeNotifier;
  late final ValueNotifier<bool> _showHorizontalLinesNotifier;

  /// GlobalKey for the drawing overlay to preserve state across rebuilds
  final GlobalKey _drawingOverlayKey = GlobalKey();

  /// Stream subscription for document changes
  late StreamSubscription _documentChangesSubscription;

  /// 防抖定时器，用于优化绘图更新性能
  Timer? _drawingUpdateDebouncer;

  /// 标记组件是否已销毁
  bool _isDisposed = false;

  /// 缓存验证后的绘图点，避免重复验证
  List<DrawingPoint>? _cachedValidatedPoints;

  /// 原始日记数据，用于检测修改
  Journal? _originalJournal;

  /// 修改状态
  bool _hasChanges = false;

  /// 绘图更新锁，防止并发更新
  bool _isUpdatingDrawing = false;

  /// 绘图点验证辅助方法，统一验证逻辑
  List<DrawingPoint> _validateDrawingPoints(List<DrawingPoint>? points) {
    if (points == null || points.isEmpty) return [];

    try {
      // 不再依赖外部锁，使用局部变量和副本避免并发问题
      final pointsCopy = List<DrawingPoint>.from(points);
      final maxAllowedPoints = _getAdaptiveMaxPoints();

      // 验证并过滤绘图点，确保每个点都是有效的
      final validatedPoints = pointsCopy
          .where((point) {
            // 增强的防御性检查
            if (!point.offset.dx.isFinite) return false;
            if (!point.offset.dy.isFinite) return false;
            return true;
          })
          .take(maxAllowedPoints) // 限制最大点数
          .toList();

      // 总是更新缓存，确保 _getAdaptiveMaxPoints 方法能获取正确的当前绘图点数量
      _cachedValidatedPoints = validatedPoints;

      // 如果验证后为空但原始数据不为空，返回原始数据的安全副本
      if (validatedPoints.isEmpty && points.isNotEmpty) {
        debugPrint(
            'Warning: Validation returned empty, preserving original points');
        _cachedValidatedPoints = points;
        return List<DrawingPoint>.from(points.take(maxAllowedPoints));
      }

      return validatedPoints;
    } catch (e, stackTrace) {
      debugPrint('Error validating drawing points: $e');
      debugPrint('Stack trace: $stackTrace');
      // 出错时返回原始数据的安全副本，避免丢失用户数据
      _cachedValidatedPoints = points;
      return List<DrawingPoint>.from(points.take(_getAdaptiveMaxPoints()));
    }
  }

  /// 获取自适应最大点数限制
  int _getAdaptiveMaxPoints() {
    // 根据当前绘图点数量动态调整限制
    final currentCount = _cachedValidatedPoints?.length ?? 0;

    if (currentCount > 3000) {
      return 3000; // 如果已经有很多点，限制增长
    } else if (currentCount > 2000) {
      return 4000; // 中等数量时适度限制
    } else {
      return 5000; // 正常情况下允许更多点
    }
  }

  /// Current background type
  BackgroundType _currentBackgroundType = BackgroundType.transparent;

  /// Background color
  Color _solidBackgroundColor = AppTheme.offWhite;

  /// Recording state
  bool _isRecording = false;

  Timer? _recordingTimer;

  /// Style panel
  bool _showStylePanel = false;

  @override
  void initState() {
    super.initState();
    // Initialize ValueNotifiers
    _brushColorNotifier = ValueNotifier<Color>(AppTheme.deepSpaceGray);
    _brushWidthNotifier = ValueNotifier<double>(3.0);
    _eraserWidthNotifier = ValueNotifier<double>(3.0);
    _isEraserModeNotifier = ValueNotifier<bool>(false);
    _showHorizontalLinesNotifier = ValueNotifier<bool>(false);

    // TODO: Load saved settings if any

    // 初始化控制器和状态
    _initializeState();
  }

  void _initializeState() {
    // 初始化标题控制器
    _titleController = TextEditingController(
      text: widget.journal?.title ?? '',
    );
    // 添加标题变化监听器
    _titleController.addListener(_checkForChanges);

    // 初始化标签列表
    _tags = widget.journal?.tags ?? [];

    // 初始化分类ID
    _categoryId = widget.journal?.categoryId ?? widget.category.id;

    // 初始化FocusNode
    _quillFocusNode = FocusNode();

    // Create and attach the focus attachment
    _focusAttachment = _quillFocusNode.attach(context);

    // 添加焦点变化监听器
    _quillFocusNode.addListener(() {
      if (_quillFocusNode.hasFocus) {
        // 获得焦点时，确保光标可见
        _controller.updateSelection(
          _controller.selection,
          flutter_quill.ChangeSource.local,
        );
      }
    });

    // 重置绘图模式状态
    _isDrawingMode = false;

    // 从journal中加载绘图数据，添加更强的防御性检查
    List<DrawingPoint> loadedPoints = [];
    try {
      if (widget.journal?.content != null &&
          widget.journal!.content.isNotEmpty) {
        try {
          // 查找绘图类型的ContentBlock
          final drawingBlock = widget.journal!.content.firstWhere(
            (block) => block.type == ContentBlockType.drawing,
            orElse: () => ContentBlock(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: ContentBlockType.drawing,
              data: '{}',
              orderIndex: 1,
            ),
          );

          // 解析绘图数据，添加多层防御性检查
          if (drawingBlock.data.isNotEmpty) {
            final dynamic parsedData = jsonDecode(drawingBlock.data);
            if (parsedData is Map && parsedData.containsKey('points')) {
              final pointsList = parsedData['points'];
              if (pointsList is List) {
                loadedPoints = pointsList
                    .where((pointJson) => pointJson is Map<String, dynamic>)
                    .map((pointJson) {
                      try {
                        return DrawingPoint.fromJson(
                            pointJson as Map<String, dynamic>);
                      } catch (e) {
                        print('Error parsing drawing point: $e');
                        return null;
                      }
                    })
                    .where((point) => point != null)
                    .cast<DrawingPoint>()
                    .toList();
              }
            }
          }
        } catch (e, stackTrace) {
          print('Error loading drawing data: $e');
          print('Stack trace: $stackTrace');
        }
      }
    } catch (e, stackTrace) {
      print('Critical error initializing drawing data: $e');
      print('Stack trace: $stackTrace');
      loadedPoints = [];
    }

    // Initialize the ValueNotifier with loaded points
    _cachedValidatedPoints = null; // 清除缓存
    _drawingPointsNotifier.value = _validateDrawingPoints(loadedPoints);

    // 初始化Quill控制器
    String quillContent = '[]'; // Default empty Quill document
    if (widget.journal?.content != null && widget.journal!.content.isNotEmpty) {
      // Get the first ContentBlock that contains Quill content
      final quillBlock = widget.journal!.content.firstWhere(
        (block) =>
            block.type == ContentBlockType.text &&
            block.attributes['type'] == 'quill',
        orElse: () => ContentBlock(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: ContentBlockType.text,
          data: '[]',
          orderIndex: 0,
          attributes: {'type': 'quill'},
        ),
      );
      quillContent = quillBlock.data;
    }

    // Ensure we have valid content that won't cause "Document Delta cannot be empty" error
    List<dynamic> decodedContent = [];
    try {
      decodedContent = jsonDecode(quillContent) as List;
    } catch (e) {
      decodedContent = [];
    }

    if (decodedContent.isEmpty) {
      decodedContent = [
        {'insert': '\n'}
      ];
    }

    final document = flutter_quill.Document.fromJson(decodedContent);

    // 保存旧的控制器引用，以便后续处理
    flutter_quill.QuillController? oldController;
    try {
      // 只有当控制器已经初始化时，才保存旧的控制器引用
      oldController = _controller;
    } catch (e) {
      // 忽略第一次初始化时的错误
      oldController = null;
    }

    // 创建新的控制器
    _controller = flutter_quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // 取消旧的订阅（如果存在）
    try {
      _documentChangesSubscription.cancel();
    } catch (e) {
      // 忽略取消失败的情况，可能是第一次初始化
    }

    // 创建新的订阅
    _documentChangesSubscription = _controller.document.changes.listen((event) {
      _onDocumentChange();
      _handleAutoCheckbox(event); // Re-enabled with crash protection
    });

    _controller.addListener(() {
      _onSelectionChanged();
    });

    _controller.addListener(_onTextChanged);

    // 移除旧控制器的监听器并dispose
    try {
      if (oldController != null && oldController != _controller) {
        oldController.removeListener(_onTextChanged);
        oldController.dispose();
      }
    } catch (e) {
      // 忽略dispose失败的情况
    }

    _initBackgroundStyle();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _quillFocusNode.requestFocus();
      }
    });

    // 保存原始日记数据，用于检测修改
    _saveOriginalJournal();
  }

  /// 保存原始日记数据
  void _saveOriginalJournal() {
    if (widget.journal != null) {
      _originalJournal = Journal(
        id: widget.journal!.id,
        categoryId: widget.journal!.categoryId,
        title: widget.journal!.title,
        content: List.from(widget.journal!.content),
        tags: List.from(widget.journal!.tags),
        date: widget.journal!.date,
        createdAt: widget.journal!.createdAt,
        updatedAt: widget.journal!.updatedAt,
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopRecording();
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // 立即取消所有绘图相关的定时器和更新
    _drawingUpdateDebouncer?.cancel();
    _drawingUpdateDebouncer = null;

    // 取消文档变化防抖定时器
    _documentChangeDebounceTimer?.cancel();
    _documentChangeDebounceTimer = null;

    // Dispose drawing ValueNotifiers
    _brushColorNotifier.dispose();
    _brushWidthNotifier.dispose();
    _eraserWidthNotifier.dispose();
    _isEraserModeNotifier.dispose();
    _showHorizontalLinesNotifier.dispose();
    _drawingPointsNotifier.dispose();

    // 安全地释放控制器资源
    try {
      _audioRecorder.dispose();
    } catch (e) {
      debugPrint('Error disposing audio recorder: $e');
    }

    try {
      _controller.removeListener(_onTextChanged);
      _titleController.removeListener(_checkForChanges);
      _documentChangesSubscription.cancel();
      _focusAttachment.detach();
      _quillFocusNode.dispose();
      _titleController.dispose();
      _controller.dispose();

      _pageScrollController.dispose();
      _cachedValidatedPoints = null;
      _isUpdatingDrawing = false;
    } catch (e) {
      debugPrint('Error disposing controllers: $e');
    }

    super.dispose();
  }

  /// 安全的绘图模式切换 - 修复版本
  void _safeToggleDrawingMode() {
    if (_isUpdatingDrawing) {
      debugPrint('Skipping toggle - currently updating drawing');
      Timer(const Duration(milliseconds: 200), () {
        if (!_isDisposed) {
          _safeToggleDrawingMode();
        }
      });
      return;
    }

    try {
      _isUpdatingDrawing = true;

      // 取消所有待处理的绘图更新
      _drawingUpdateDebouncer?.cancel();
      _drawingUpdateDebouncer = null;

      if (_isDrawingMode) {
        // 退出绘图模式 - 保存数据
        debugPrint('Exiting drawing mode and saving data...');

        // 1. 先获取当前所有绘图点，添加安全检查
        final currentPointsValue = _drawingPointsNotifier.value;
        final currentPoints = List<DrawingPoint>.from(currentPointsValue);
        debugPrint('Current points before save: ${currentPoints.length}');

        // 2. 简单验证点，只过滤绝对无效的点
        List<DrawingPoint> validPoints = [];
        for (final point in currentPoints) {
          // 只过滤无效坐标，保留所有其他点
          if (!point.offset.dx.isFinite || !point.offset.dy.isFinite) continue;

          // 允许原点(0,0) - 这是有效坐标
          validPoints.add(point);
        }

        // 3. 确保有结束标记
        if (validPoints.isNotEmpty && !validPoints.last.isEndOfStroke) {
          final lastPoint = validPoints.last;
          validPoints.add(DrawingPoint(
            offset: lastPoint.offset,
            color: lastPoint.color,
            width: lastPoint.width,
            isEndOfStroke: true,
          ));
        }

        // 4. 智能限制点数，保留完整的笔画
        if (validPoints.length > 5000) {
          debugPrint('Points exceeded limit, preserving most recent strokes');
          // 从后往前遍历，保留完整的笔画，直到达到限制
          final limitedPoints = <DrawingPoint>[];

          // 先添加最新的笔画
          for (int i = validPoints.length - 1;
              i >= 0 && limitedPoints.length < 5000;
              i--) {
            final point = validPoints[i];
            limitedPoints.insert(0, point);

            // 遇到结束标记，说明我们已经完整地保留了一笔
            if (point.isEndOfStroke) break;
          }

          // 如果还有空间，添加更早的笔画
          if (limitedPoints.length < 5000) {
            for (int i = 0;
                i < validPoints.length - limitedPoints.length &&
                    limitedPoints.length < 5000;
                i++) {
              final point = validPoints[i];
              limitedPoints.add(point);

              // 遇到结束标记，说明我们已经完整地保留了一笔
              if (point.isEndOfStroke) continue;
            }
          }

          validPoints = limitedPoints;
          debugPrint(
              'Reduced points from ${currentPoints.length} to ${validPoints.length}');
        }

        // 5. 更新绘图点 - 只在有有效点时更新，否则保留原数据，添加安全检查
        final updatedPoints = validPoints.isNotEmpty
            ? validPoints
            : (currentPoints.isNotEmpty ? currentPoints : <DrawingPoint>[]);

        if (!_isDisposed && mounted) {
          _drawingPointsNotifier.value = updatedPoints;
          _cachedValidatedPoints = updatedPoints; // 同步更新缓存
          debugPrint(
              'Drawing mode exited, saved ${updatedPoints.length} points');
        }

        // 6. 更新状态
        _isDrawingMode = false;

        _quillFocusNode.requestFocus();
      } else {
        // 进入绘图模式
        debugPrint('Entering drawing mode...');

        _isDrawingMode = true;

        // 清理缓存，重新加载已保存的点
        _cachedValidatedPoints = null;

        // 确保当前点的有效性
        final currentPoints = _drawingPointsNotifier.value;
        if (currentPoints.isNotEmpty) {
          debugPrint(
              'Entering drawing mode with ${currentPoints.length} existing points');
        } else {
          debugPrint('Entering drawing mode with empty canvas');
        }
      }

      debugPrint('Drawing mode toggled to: $_isDrawingMode');
    } catch (e, stackTrace) {
      debugPrint('Error toggling drawing mode: $e');
      debugPrint('Stack trace: $stackTrace');

      // 安全回退
      _isDrawingMode = false;
      _quillFocusNode.requestFocus();
    } finally {
      _isUpdatingDrawing = false;
    }

    // 确保在组件未销毁时调用setState
    if (!_isDisposed) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant MinimalJournalEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当日记变化时，重新初始化状态
    if (oldWidget.journal?.id != widget.journal?.id) {
      _initializeState();
    }
  }

  void _initBackgroundStyle() {}

  /// 防抖定时器，用于优化文档变化时的重新渲染
  Timer? _documentChangeDebounceTimer;

  void _onDocumentChange() {
    // 使用防抖避免频繁的重新渲染，特别是在中文输入时
    try {
      // 取消之前的定时器
      _documentChangeDebounceTimer?.cancel();
      
      // 设置新的定时器，延迟300毫秒执行
      _documentChangeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        // 只在非绘图模式下调用 setState，以避免无限循环
        if (!_isDrawingMode && mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      // 忽略任何可能的异常，以避免崩溃
      debugPrint('Error in _onDocumentChange: $e');
    }
  }

  void _onSelectionChanged() {}

  void _handleCheckboxToggle(String id, bool currentStatus) {
    debugPrint('_handleCheckboxToggle called: id=$id, current=$currentStatus');

    final doc = _controller.document;
    final delta = doc.toDelta();
    int offset = 0;

    for (final op in delta.toList()) {
      if (op.data is Map) {
        final data = op.data as Map;
        Map<String, dynamic>? checkboxData;
        bool found = false;

        // 检查多种复选框格式
        if (data.containsKey('custom')) {
          try {
            final customData = data['custom'];
            if (customData is String) {
              try {
                checkboxData = jsonDecode(customData);
                found = checkboxData != null && checkboxData['id'] == id;
              } catch (e) {
                // 尝试处理损坏的格式
                if (customData.contains(id)) {
                  checkboxData = {'id': id, 'checked': currentStatus};
                  found = true;
                }
              }
            } else if (customData is Map) {
              checkboxData = Map<String, dynamic>.from(customData);
              found = checkboxData['id'] == id;
            }
          } catch (e) {
            debugPrint('Error processing custom checkbox: $e');
          }
        }

        // 直接检查checkbox字段
        if (!found && data.containsKey('checkbox')) {
          try {
            final checkboxField = data['checkbox'];
            if (checkboxField is Map) {
              checkboxData = Map<String, dynamic>.from(checkboxField);
              found = checkboxData['id'] == id;
            } else if (checkboxField is String) {
              checkboxData = jsonDecode(checkboxField);
              found = checkboxData != null && checkboxData['id'] == id;
            }
          } catch (e) {
            debugPrint('Error processing direct checkbox: $e');
          }
        }

        if (found && checkboxData != null) {
          final newChecked = !currentStatus;

          // 确保使用一致的格式
          final newData = jsonEncode({'id': id, 'checked': newChecked});

          debugPrint(
              'MinimalJournalEditor._handleCheckboxToggle: TOGGLING checkbox at $offset');
          _controller.replaceText(
            offset,
            1,
            flutter_quill.BlockEmbed.custom(
                flutter_quill.CustomBlockEmbed('checkbox', newData)),
            null,
          );

          // 更新行内文本样式
          final text = doc.toPlainText();
          int lineEnd = text.indexOf('\n', offset);
          if (lineEnd == -1) lineEnd = text.length;

          final textLen = lineEnd - (offset + 1);
          if (textLen > 0) {
            if (newChecked) {
              _controller.formatText(
                  offset + 1, textLen, flutter_quill.Attribute.strikeThrough);
              _controller.formatText(offset + 1, textLen,
                  flutter_quill.Attribute.fromKeyValue('color', '#9e9e9e'));
            } else {
              _controller.formatText(
                  offset + 1,
                  textLen,
                  flutter_quill.Attribute.clone(
                      flutter_quill.Attribute.strikeThrough, null));
              _controller.formatText(offset + 1, textLen,
                  flutter_quill.Attribute.fromKeyValue('color', '#000000'));
            }
          }

          return;
        }
      }
      offset += (op.length ?? 0).toInt();
    }
  }

  void _handleAutoCheckbox(flutter_quill.DocChange event) {
    // 防止无限循环：如果已经在处理复选框，直接返回
    if (_isHandlingCheckbox) return;

    if (event.source != flutter_quill.ChangeSource.local) return;

    bool hasNewline = false;
    bool hasOnlyNewline = true;
    bool hasChineseInput = false;
    final delta = event.change;
    for (final op in delta.toList()) {
      if (op.key == 'insert' && op.value is String) {
        final value = op.value as String;
        if (value.contains('\n')) {
          hasNewline = true;
        }
        if (value.length > 1 || (value.length == 1 && value != '\n')) {
          hasOnlyNewline = false;
        }
        // 检查是否包含中文字符
        if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(value)) {
          hasChineseInput = true;
        }
      } else if (op.key == 'insert' && op.value is! String) {
        // 插入的不是文本，可能是嵌入，跳过
        hasOnlyNewline = false;
      }
    }

    // 只在真正的换行操作时触发，而不是在输入法处理过程中
    // 跳过中文输入的处理，以避免干扰嵌入的渲染
    if (hasNewline && hasOnlyNewline && !hasChineseInput) {
      Future.microtask(() {
        if (!mounted) return;

        final selection = _controller.selection;
        if (!selection.isCollapsed) return;

        final cursorPosition = selection.baseOffset;
        if (cursorPosition == 0) return;

        final doc = _controller.document;
        final text = doc.toPlainText();

        if (cursorPosition > 0 &&
            cursorPosition <= text.length &&
            text[cursorPosition - 1] == '\n') {
          final prevLineEnd = cursorPosition - 1;

          // 修复边界条件：当光标在文档开头的换行符后时，prevLineEnd - 1可能为负数
          final prevLineStart =
              prevLineEnd > 0 ? text.lastIndexOf('\n', prevLineEnd - 1) : -1;
          final start = prevLineStart == -1 ? 0 : prevLineStart + 1;

          // 检查前一行开头是否有复选框
          bool prevLineHasCheckbox = _hasCheckboxAt(start);

          // 仅当当前行开头有复选框时，才在新行自动插入复选框
          if (prevLineHasCheckbox) {
            // 检查前一行是否只有复选框（空行情况）
            final prevLineLength = prevLineEnd - start;
            if (prevLineLength <= 1) {
              // 前一行只有复选框，删除它
              _isHandlingCheckbox = true;
              try {
                _controller.replaceText(start, prevLineLength, '', null);
              } finally {
                _isHandlingCheckbox = false;
              }
            } else {
              // 在新行插入复选框嵌入
              final checkboxId =
                  DateTime.now().millisecondsSinceEpoch.toString();
              final checkboxData =
                  jsonEncode({'id': checkboxId, 'checked': false});

              // 在新行插入复选框嵌入，防止无限循环
              _isHandlingCheckbox = true;
              try {
                _controller.replaceText(
                    selection.start,
                    selection.extentOffset - selection.start,
                    flutter_quill.BlockEmbed.custom(
                        flutter_quill.CustomBlockEmbed(
                            'checkbox', checkboxData)),
                    TextSelection.collapsed(offset: selection.start + 1));
              } finally {
                _isHandlingCheckbox = false;
              }

              // 移除IME干扰修复逻辑，只单纯插入
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _quillFocusNode.requestFocus();
                }
              });
            }
          }
        }
      });
    }
  }

  bool _hasCheckboxAt(int offset) {
    final delta = _controller.document.toDelta();
    int currentOffset = 0;
    for (final op in delta.toList()) {
      if (currentOffset == offset) {
        if (op.data is Map) {
          final data = op.data as Map;

          // 检查直接的checkbox字段
          if (data.containsKey('checkbox')) {
            return true;
          }

          // 检查嵌入类型是否为checkbox
          if (data.isNotEmpty) {
            final embedType = data.keys.first;
            if (embedType == 'checkbox') {
              return true;
            }

            // 对于custom类型，需要进一步检查其内容
            if (embedType == 'custom') {
              try {
                final customData = data['custom'];
                if (customData is String) {
                  // 解析custom数据，检查是否为复选框
                  final decoded = jsonDecode(customData);
                  if (decoded is Map &&
                      (decoded.containsKey('checkbox') ||
                          (decoded.containsKey('id') &&
                              decoded.containsKey('checked') &&
                              !decoded.containsKey('drawing') &&
                              !decoded.containsKey('points') &&
                              !decoded.containsKey('image') &&
                              !decoded.containsKey('video') &&
                              !decoded.containsKey('audio') &&
                              !decoded.containsKey('file')))) {
                    return true;
                  }
                } else if (customData is Map) {
                  // 直接检查custom Map是否包含复选框特征
                  if (customData.containsKey('checkbox') ||
                      (customData.containsKey('id') &&
                          customData.containsKey('checked') &&
                          !customData.containsKey('drawing') &&
                          !customData.containsKey('points') &&
                          !customData.containsKey('image') &&
                          !customData.containsKey('video') &&
                          !customData.containsKey('audio') &&
                          !customData.containsKey('file'))) {
                    return true;
                  }
                }
              } catch (e) {
                // 解析失败，不是复选框
              }
            }
          }
        }
        return false;
      }
      currentOffset += (op.length ?? 0).toInt();
      if (currentOffset > offset) return false;
    }
    return false;
  }

  void _onTextChanged() {
    debugPrint(
        'MinimalJournalEditor._onTextChanged: Text changed. Current document length: ${_controller.document.length}');
    if (_isDeletingCheckbox) {
      _isDeletingCheckbox = false;
      return;
    }
    
    // 打印日记内容，分析输入中文前后的变化
    _printJournalContent();
    
    // 检测修改
    _checkForChanges();
  }

  /// 打印日记内容，用于分析输入中文前后的变化
  void _printJournalContent() {
    try {
      final delta = _controller.document.toDelta();
      final quillJson = jsonEncode(delta.toJson());
      
      debugPrint('=== 日记内容分析 ===');
      debugPrint('Document length: ${delta.length}');
      debugPrint('Document JSON (first 1000 chars): ${quillJson.substring(0, math.min(1000, quillJson.length))}...');
      
      // 分析嵌入数据
      int embedCount = 0;
      for (final op in delta.toList()) {
        if (op.data is Map) {
          final dataMap = op.data as Map;
          embedCount++;
          debugPrint('Embed $embedCount: ${jsonEncode(dataMap)}');
          
          if (dataMap.containsKey('custom')) {
            final customData = dataMap['custom'];
            debugPrint('  Custom data type: ${customData.runtimeType}');
            debugPrint('  Custom data value: $customData');
            
            if (customData is String && customData == 'OBJ') {
              debugPrint('  !!! DETECTED OBJ STRING IN EMBED !!!');
            }
          }
        }
      }
      
      debugPrint('Total embeds found: $embedCount');
      debugPrint('=== 日记内容分析结束 ===');
    } catch (e) {
      debugPrint('Error printing journal content: $e');
    }
  }

  /// 检测是否有修改
  void _checkForChanges() {
    if (_hasChanges) return; // 已经检测到修改，无需重复检查

    if (_originalJournal == null) {
      // 新日记，默认有修改
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 检查标题是否变化
    if (_titleController.text != _originalJournal!.title) {
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 检查分类是否变化
    if (_categoryId != _originalJournal!.categoryId) {
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 检查标签是否变化
    if (_tags != _originalJournal!.tags) {
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 检查文本内容是否变化
    final currentQuillJson =
        jsonEncode(_controller.document.toDelta().toJson());
    String originalQuillJson = '[]';
    if (_originalJournal!.content.isNotEmpty) {
      final textBlock = _originalJournal!.content.firstWhere(
        (block) =>
            block.type == ContentBlockType.text &&
            block.attributes['type'] == 'quill',
        orElse: () => ContentBlock(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: ContentBlockType.text,
          data: '[]',
          orderIndex: 0,
          attributes: {'type': 'quill'},
        ),
      );
      originalQuillJson = textBlock.data;
    }
    if (currentQuillJson != originalQuillJson) {
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 检查绘图内容是否变化
    final currentDrawingPoints = _drawingPointsNotifier.value;
    List<DrawingPoint> originalDrawingPoints = [];
    if (_originalJournal!.content.isNotEmpty) {
      final drawingBlock = _originalJournal!.content.firstWhere(
        (block) => block.type == ContentBlockType.drawing,
        orElse: () => ContentBlock(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: ContentBlockType.drawing,
          data: '{}',
          orderIndex: 1,
        ),
      );
      if (drawingBlock.data.isNotEmpty) {
        final parsedData = jsonDecode(drawingBlock.data);
        if (parsedData is Map && parsedData.containsKey('points')) {
          final pointsList = parsedData['points'];
          if (pointsList is List) {
            originalDrawingPoints = pointsList
                .where((pointJson) => pointJson is Map<String, dynamic>)
                .map((pointJson) {
                  try {
                    return DrawingPoint.fromJson(
                        pointJson as Map<String, dynamic>);
                  } catch (e) {
                    print('Error parsing drawing point: $e');
                    return null;
                  }
                })
                .where((point) => point != null)
                .cast<DrawingPoint>()
                .toList();
          }
        }
      }
    }
    // 比较绘图点列表是否相等
    if (!_areDrawingPointsEqual(currentDrawingPoints, originalDrawingPoints)) {
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    // 没有修改
    setState(() {
      _hasChanges = false;
    });
  }

  /// 比较两个绘图点列表是否相等
  bool _areDrawingPointsEqual(
      List<DrawingPoint> list1, List<DrawingPoint> list2) {
    if (list1.length != list2.length) {
      return false;
    }
    for (int i = 0; i < list1.length; i++) {
      final point1 = list1[i];
      final point2 = list2[i];
      if (point1.offset != point2.offset ||
          point1.color != point2.color ||
          point1.width != point2.width ||
          point1.isEndOfStroke != point2.isEndOfStroke) {
        return false;
      }
    }
    return true;
  }

  /// 简化的复选框处理机制，避免与IME冲突
  /// 不再使用复杂的修复机制，而是采用更简单、更可靠的方式处理复选框

  /// Update all video widths in the document from VideoWidthManager
  Future<void> _updateVideoWidths() async {
    final manager = VideoWidthManager();
    final widths = manager.getAllWidths();

    if (widths.isEmpty) {
      debugPrint('[Save] No video widths to update');
      return;
    }

    debugPrint('[Save] Updating ${widths.length} video widths');

    // Get current document delta
    final delta = _controller.document.toDelta();
    int offset = 0;

    // Find and update all video embeds
    for (int i = 0; i < delta.length; i++) {
      final op = delta.toList()[i];

      if (op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('custom')) {
          try {
            final customData = data['custom'];
            Map<String, dynamic> videoData;

            if (customData is String) {
              videoData = jsonDecode(customData);
            } else if (customData is Map) {
              videoData = Map<String, dynamic>.from(customData);
            } else {
              offset += (op.length ?? 1).toInt();
              continue;
            }

            // Check if this is a video embed
            if (videoData.containsKey('video')) {
              final videoInfo = videoData['video'];
              String? videoPath;

              if (videoInfo is String) {
                try {
                  final parsed = jsonDecode(videoInfo);
                  if (parsed is Map && parsed.containsKey('path')) {
                    videoPath = parsed['path'];
                  }
                } catch (_) {
                  videoPath = videoInfo;
                }
              } else if (videoInfo is Map && videoInfo.containsKey('path')) {
                videoPath = videoInfo['path'];
              }

              // If we have a pending width for this video, update it
              if (videoPath != null && widths.containsKey(videoPath)) {
                final newWidth = widths[videoPath]!;
                debugPrint(
                    '[Save] Updating video at offset \$offset: \$videoPath -> width \$newWidth');

                final newVideoData = jsonEncode({
                  'path': videoPath,
                  'width': newWidth,
                });

                _controller.replaceText(
                  offset,
                  1,
                  flutter_quill.BlockEmbed.custom(
                      flutter_quill.CustomBlockEmbed('video', newVideoData)),
                  TextSelection.collapsed(offset: offset),
                );
              }
            }
          } catch (e) {
            debugPrint('[Save] Error updating video at offset \$offset: \$e');
          }
        }
      }

      offset += (op.length ?? 1).toInt();
    }

    // Clear the manager after updating
    manager.clearAll();
    debugPrint('[Save] Video widths updated and manager cleared');
  }

  Future<void> _saveJournal() async {
    // Cleanup unused files before saving
    await _cleanupUnusedFiles();

    // Update video widths from VideoWidthManager before saving
    await _updateVideoWidths();



    // Get the final Delta after all syncs are done
    final quillDelta = _controller.document.toDelta();
    final quillJson = jsonEncode(quillDelta.toJson());
    debugPrint('=== _saveJournal() after sync ===');
    debugPrint('Quill document length: ${quillDelta.length}');
    debugPrint(
        'Quill document content (first 1000 chars): ${quillJson.substring(0, math.min(1000, quillJson.length))}...');

    // Check if the Delta actually contains any drawing embeds with points
    int drawingsFoundInDelta = 0;
    for (final op in quillDelta.toList()) {
      if (op.data is Map) {
        final data = op.data as Map;
        if (data.containsKey('drawing') || data.containsKey('custom')) {
          drawingsFoundInDelta++;
          debugPrint('Found drawing/custom embed in final Delta: ${op.data}');
        }
      }
    }
    debugPrint(
        'Total drawing/custom embeds found in final Delta: $drawingsFoundInDelta');

    final Map<String, dynamic> textAttributes = {
      'type': 'quill',
    };

    // Create the text content block
    final textBlock = ContentBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ContentBlockType.text,
      data: quillJson,
      orderIndex: 0,
      attributes: textAttributes,
    );

    // Create content blocks list
    final List<ContentBlock> contentBlocks = [textBlock];

    // Add drawing data to content blocks (ONLY page-level drawing)
    // NOTE: Embedded drawings are already inside the 'quillJson' data
    final pagePoints = _validateDrawingPoints(_drawingPointsNotifier.value);

    if (pagePoints.isNotEmpty) {
      final drawingJson = jsonEncode({
        'points': pagePoints.map((point) => point.toJson()).toList(),
      });

      contentBlocks.add(ContentBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_drawing',
        type: ContentBlockType.drawing,
        data: drawingJson,
        orderIndex: 1,
      ));
      debugPrint(
          'Saved PAGE-LEVEL drawing content block with ${pagePoints.length} points');
    }

    final journal = Journal(
      id: widget.journal?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      categoryId: _categoryId,
      title: _titleController.text,
      content: contentBlocks,
      tags: _tags,
      date: widget.journal?.date ?? DateTime.now(),
      createdAt: widget.journal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(journal);
  }

  Future<void> _cleanupUnusedFiles() async {
    try {
      debugPrint('=== Starting file cleanup ===');
      // Get user ID for storage directory
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'default';
      final storageService = StorageService();

      // 1. Get all file paths currently in the editor
      final currentPaths = <String>{};
      debugPrint('Current user ID: $userId');
      debugPrint(
          'Current document delta: ${_controller.document.toDelta().toJson()}');
      debugPrint('=== Current paths extraction start ===');
      final delta = _controller.document.toDelta();
      for (final op in delta.toList()) {
        if (op.data is Map) {
          final data = op.data as Map;

          // Extract paths from standard embeds
          if (data.containsKey('image')) {
            final imagePath = data['image'] as String;
            currentPaths.add(imagePath);
          }

          // Extract paths from custom embeds
          if (data.containsKey('custom')) {
            final customData = data['custom'];
            Map<String, dynamic> embedData;

            if (customData is String) {
              try {
                embedData = jsonDecode(customData);
              } catch (e) {
                debugPrint('Error parsing custom embed data: $e');
                continue;
              }
            } else if (customData is Map) {
              embedData = Map<String, dynamic>.from(customData);
            } else {
              continue;
            }

            // Handle different embed types
            if (embedData.containsKey('image')) {
              final imageInfo = embedData['image'];
              if (imageInfo is String) {
                try {
                  // Try to parse as JSON string containing image data
                  final imageMap = jsonDecode(imageInfo);
                  if (imageMap is Map && imageMap.containsKey('path')) {
                    currentPaths.add(imageMap['path']);
                  } else {
                    currentPaths.add(imageInfo);
                  }
                } catch (e) {
                  // If parsing fails, use as-is
                  currentPaths.add(imageInfo);
                }
              } else if (imageInfo is Map && imageInfo.containsKey('path')) {
                currentPaths.add(imageInfo['path']);
              }
            } else if (embedData.containsKey('video')) {
              final videoInfo = embedData['video'];
              if (videoInfo is String) {
                try {
                  // Try to parse as JSON string containing video data
                  final videoMap = jsonDecode(videoInfo);
                  if (videoMap is Map && videoMap.containsKey('path')) {
                    currentPaths.add(videoMap['path']);
                  } else {
                    currentPaths.add(videoInfo);
                  }
                } catch (e) {
                  // If parsing fails, use as-is
                  currentPaths.add(videoInfo);
                }
              } else if (videoInfo is Map && videoInfo.containsKey('path')) {
                currentPaths.add(videoInfo['path']);
              }
            } else if (embedData.containsKey('audio')) {
              final audioInfo = embedData['audio'];
              if (audioInfo is String) {
                try {
                  // Try to parse as JSON string containing audio data
                  final audioMap = jsonDecode(audioInfo);
                  if (audioMap is Map && audioMap.containsKey('path')) {
                    currentPaths.add(audioMap['path']);
                  } else {
                    currentPaths.add(audioInfo);
                  }
                } catch (e) {
                  // If parsing fails, use as-is
                  currentPaths.add(audioInfo);
                }
              } else if (audioInfo is Map && audioInfo.containsKey('path')) {
                currentPaths.add(audioInfo['path']);
              }
            } else if (embedData.containsKey('file')) {
              final fileInfo = embedData['file'];
              if (fileInfo is String) {
                try {
                  // Try to parse as JSON string containing file data
                  final fileMap = jsonDecode(fileInfo);
                  if (fileMap is Map && fileMap.containsKey('path')) {
                    currentPaths.add(fileMap['path']);
                  } else {
                    currentPaths.add(fileInfo);
                  }
                } catch (e) {
                  // If parsing fails, use as-is
                  currentPaths.add(fileInfo);
                }
              } else if (fileInfo is Map && fileInfo.containsKey('path')) {
                currentPaths.add(fileInfo['path']);
              }
            }
            // Also handle direct embed formats where the value is already the path
            else if (embedData.values.first is String) {
              final path = embedData.values.first as String;
              currentPaths.add(path);
            } else if (embedData.values.first is Map &&
                (embedData.values.first as Map).containsKey('path')) {
              final path = (embedData.values.first as Map)['path'] as String;
              currentPaths.add(path);
            }
          }
        }
      }

      debugPrint('=== Current paths extraction completed ===');
      debugPrint('Current paths: $currentPaths');
      debugPrint(
          'Current filenames: ${currentPaths.map((p) => path.basename(p)).toSet()}');

      // 2. Get original paths from the journal content
      debugPrint('=== Original paths extraction start ===');
      debugPrint('Widget journal exists: ${widget.journal != null}');
      debugPrint(
          'Widget journal content length: ${widget.journal?.content.length ?? 0}');
      final originalPaths = <String>{};
      if (widget.journal != null && widget.journal!.content.isNotEmpty) {
        for (final block in widget.journal!.content) {
          if (block.type == ContentBlockType.text &&
              block.attributes['type'] == 'quill') {
            try {
              final decoded = jsonDecode(block.data) as List;
              final doc = flutter_quill.Document.fromJson(decoded);
              final delta = doc.toDelta();
              for (final op in delta.toList()) {
                if (op.data is Map) {
                  final data = op.data as Map;

                  // Extract paths from standard embeds
                  if (data.containsKey('image')) {
                    final imagePath = data['image'] as String;
                    originalPaths.add(imagePath);
                  }

                  // Extract paths from custom embeds
                  if (data.containsKey('custom')) {
                    final customData = data['custom'];
                    Map<String, dynamic> embedData;

                    if (customData is String) {
                      try {
                        embedData = jsonDecode(customData);
                      } catch (e) {
                        debugPrint(
                            'Error parsing original custom embed data: $e');
                        continue;
                      }
                    } else if (customData is Map) {
                      embedData = Map<String, dynamic>.from(customData);
                    } else {
                      continue;
                    }

                    // Handle different embed types
                    if (embedData.containsKey('image')) {
                      final imageInfo = embedData['image'];
                      if (imageInfo is String) {
                        try {
                          // Try to parse as JSON string containing image data
                          final imageMap = jsonDecode(imageInfo);
                          if (imageMap is Map && imageMap.containsKey('path')) {
                            originalPaths.add(imageMap['path']);
                          } else {
                            originalPaths.add(imageInfo);
                          }
                        } catch (e) {
                          // If parsing fails, use as-is
                          originalPaths.add(imageInfo);
                        }
                      } else if (imageInfo is Map &&
                          imageInfo.containsKey('path')) {
                        originalPaths.add(imageInfo['path']);
                      }
                    } else if (embedData.containsKey('video')) {
                      final videoInfo = embedData['video'];
                      if (videoInfo is String) {
                        try {
                          // Try to parse as JSON string containing video data
                          final videoMap = jsonDecode(videoInfo);
                          if (videoMap is Map && videoMap.containsKey('path')) {
                            originalPaths.add(videoMap['path']);
                          } else {
                            originalPaths.add(videoInfo);
                          }
                        } catch (e) {
                          // If parsing fails, use as-is
                          originalPaths.add(videoInfo);
                        }
                      } else if (videoInfo is Map &&
                          videoInfo.containsKey('path')) {
                        originalPaths.add(videoInfo['path']);
                      }
                    } else if (embedData.containsKey('audio')) {
                      final audioInfo = embedData['audio'];
                      if (audioInfo is String) {
                        try {
                          // Try to parse as JSON string containing audio data
                          final audioMap = jsonDecode(audioInfo);
                          if (audioMap is Map && audioMap.containsKey('path')) {
                            originalPaths.add(audioMap['path']);
                          } else {
                            originalPaths.add(audioInfo);
                          }
                        } catch (e) {
                          // If parsing fails, use as-is
                          originalPaths.add(audioInfo);
                        }
                      } else if (audioInfo is Map &&
                          audioInfo.containsKey('path')) {
                        originalPaths.add(audioInfo['path']);
                      }
                    } else if (embedData.containsKey('file')) {
                      final fileInfo = embedData['file'];
                      if (fileInfo is String) {
                        try {
                          // Try to parse as JSON string containing file data
                          final fileMap = jsonDecode(fileInfo);
                          if (fileMap is Map && fileMap.containsKey('path')) {
                            originalPaths.add(fileMap['path']);
                          } else {
                            originalPaths.add(fileInfo);
                          }
                        } catch (e) {
                          // If parsing fails, use as-is
                          originalPaths.add(fileInfo);
                        }
                      } else if (fileInfo is Map &&
                          fileInfo.containsKey('path')) {
                        originalPaths.add(fileInfo['path']);
                      }
                    }
                    // Also handle direct embed formats where the value is already the path
                    else if (embedData.values.first is String) {
                      final path = embedData.values.first as String;
                      originalPaths.add(path);
                    } else if (embedData.values.first is Map &&
                        (embedData.values.first as Map).containsKey('path')) {
                      final path =
                          (embedData.values.first as Map)['path'] as String;
                      originalPaths.add(path);
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error processing original journal content: $e');
            }
          }
        }
      }

      debugPrint('=== Original paths extraction completed ===');
      debugPrint('Original paths: $originalPaths');
      debugPrint(
          'Original filenames: ${originalPaths.map((p) => path.basename(p)).toSet()}');

      // 3. Find paths that are in original but NOT in current
      // Also check for filename-only matches, since old entries might use filenames instead of full paths
      final unusedPaths = <String>{};

      // Get just filenames from current paths for comparison
      final currentFilenames =
          currentPaths.map((p) => path.basename(p)).toSet();
      debugPrint('Current filenames: $currentFilenames');

      for (final originalPath in originalPaths) {
        debugPrint('Checking original path: $originalPath');
        // Check if the original path is in current paths
        if (!currentPaths.contains(originalPath)) {
          // Check if just the filename is in current filenames
          final originalFilename = path.basename(originalPath);
          debugPrint(
              'Original path not in current paths, checking filename: $originalFilename');
          if (!currentFilenames.contains(originalFilename)) {
            unusedPaths.add(originalPath);
            debugPrint('Added to unused paths: $originalPath');
          } else {
            debugPrint(
                'Filename $originalFilename is still in use, skipping deletion');
          }
        } else {
          debugPrint(
              'Original path is still in current paths, skipping deletion');
        }
      }

      debugPrint('=== Unused files analysis completed ===');
      debugPrint(
          'Found ${unusedPaths.length} unused files to delete: $unusedPaths');

      // 4. Delete unused files using StorageService
      for (final filePath in unusedPaths) {
        debugPrint('Attempting to delete unused file: $filePath');
        try {
          await storageService.deleteFile(filePath);
          debugPrint('✓ Deleted unused file: $filePath');
        } catch (e) {
          debugPrint('✗ Error deleting file $filePath: $e');
        }
      }

      debugPrint('=== File cleanup completed ===');
    } catch (e) {
      debugPrint('Error cleaning up files: $e');
    }
  }

  Future<void> _insertImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result != null) {
      try {
        // Save image to local storage and get full path
        final newPath = await _moveFileToSettingsDir(result.path, 'images');
        if (newPath != null) {
          // Use the full path in the editor
          final selection = _controller.selection;
          _controller.replaceText(
            selection.start,
            selection.extentOffset - selection.start,
            flutter_quill.BlockEmbed.image(newPath),
            TextSelection.collapsed(offset: selection.start + 1),
          );
          // 确保光标移动到图片后
          _controller.updateSelection(
            TextSelection.collapsed(offset: selection.start + 1),
            flutter_quill.ChangeSource.local,
          );
          _quillFocusNode.requestFocus();
        }
      } catch (e) {
        debugPrint('Error inserting image: $e');
      }
    }
  }

  Future<String?> _moveFileToSettingsDir(String sourcePath,
      [String subDirName = 'files']) async {
    if (kIsWeb) return sourcePath;

    try {
      // 获取当前用户ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'default';

      // 使用StorageService处理文件存储
      final storageService = StorageService();
      final xFile = XFile(sourcePath);

      String? storedPath;

      // 根据子目录名称选择相应的存储方法
      switch (subDirName) {
        case 'images':
          storedPath = await storageService.storeImage(xFile, userId: userId);
          break;
        case 'audios':
          storedPath = await storageService.storeAudio(xFile, userId: userId);
          break;
        case 'videos':
          storedPath = await storageService.storeVideo(xFile, userId: userId);
          break;
        default:
          storedPath = await storageService.storeFile(xFile, userId: userId);
          break;
      }

      return storedPath;
    } catch (e) {
      debugPrint('Error moving file: $e');
      return null;
    }
  }

  /// Start audio recording with dialog
  Future<void> _startRecording() async {
    try {
      // Check and request permission
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('No recording permission');
        return;
      }

      // Start recording
      String fileName =
          'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final tempPath =
          path.join((await getTemporaryDirectory()).path, fileName);
      await _audioRecorder.start(const RecordConfig(), path: tempPath);
      setState(() {
        _isRecording = true;
      });

      // Show recording dialog
      final result = await showDialog<RecordingResult?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AudioRecordingDialog(
          recorder: _audioRecorder,
          tempPath: tempPath,
          fileName: fileName,
        ),
      );

      if (result != null && result.save) {
        // Move the recorded file to storage dir
        final newPath = await _moveFileToSettingsDir(tempPath, 'audios');
        if (newPath != null) {
          final selection = _controller.selection;
          final audioData = {'path': newPath, 'name': result.fileName};
          _controller.replaceText(
            selection.start,
            selection.extentOffset - selection.start,
            flutter_quill.BlockEmbed.custom(
                flutter_quill.CustomBlockEmbed('audio', jsonEncode(audioData))),
            null,
          );
          _controller.document.insert(selection.start + 1, '\n');
          _controller.updateSelection(
            TextSelection.collapsed(offset: selection.start + 2),
            flutter_quill.ChangeSource.local,
          );
          _quillFocusNode.requestFocus();
        }
      } else {
        // Delete the temporary file if not saved
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    } finally {
      setState(() {
        _isRecording = false;
      });
    }
  }

  /// Stop recording
  Future<void> _stopRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  /// Insert existing audio file
  Future<void> _insertAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final newPath = await _moveFileToSettingsDir(file.path!, 'audios');
        if (newPath != null) {
          final selection = _controller.selection;
          final audioData = {'path': newPath, 'name': file.name};
          _controller.replaceText(
            selection.start,
            selection.extentOffset - selection.start,
            flutter_quill.BlockEmbed.custom(
                flutter_quill.CustomBlockEmbed('audio', jsonEncode(audioData))),
            null,
          );
          _controller.document.insert(selection.start + 1, '\n');
          _controller.updateSelection(
            TextSelection.collapsed(offset: selection.start + 2),
            flutter_quill.ChangeSource.local,
          );
          _quillFocusNode.requestFocus();
        }
      }
    } catch (e) {
      debugPrint('Error inserting audio: $e');
    }
  }

  Future<void> _insertVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final newPath = await _moveFileToSettingsDir(file.path!, 'videos');
        if (newPath != null) {
          final selection = _controller.selection;
          final videoData = {'path': newPath, 'name': file.name};
          _controller.replaceText(
            selection.start,
            selection.extentOffset - selection.start,
            flutter_quill.BlockEmbed.custom(
                flutter_quill.CustomBlockEmbed('video', jsonEncode(videoData))),
            null,
          );
          _controller.document.insert(selection.start + 1, '\n');
          _controller.updateSelection(
            TextSelection.collapsed(offset: selection.start + 2),
            flutter_quill.ChangeSource.local,
          );
          _quillFocusNode.requestFocus();
        }
      }
    } catch (e) {
      debugPrint('Error inserting video: $e');
    }
  }

  Future<void> _insertMoreFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final newPath = await _moveFileToSettingsDir(file.path!, 'files');
        if (newPath != null) {
          final selection = _controller.selection;
          final extension = path.extension(file.name).replaceAll('.', '');
          final fileData = {
            'path': newPath,
            'name': file.name,
            'type': extension,
          };
          _controller.replaceText(
            selection.start,
            selection.extentOffset - selection.start,
            flutter_quill.BlockEmbed.custom(
                flutter_quill.CustomBlockEmbed('file', jsonEncode(fileData))),
            null,
          );
          _controller.document.insert(selection.start + 1, '\n');
          _controller.updateSelection(
            TextSelection.collapsed(offset: selection.start + 2),
            flutter_quill.ChangeSource.local,
          );
          _quillFocusNode.requestFocus();
        }
      }
    } catch (e) {
      debugPrint('Error inserting file: $e');
    }
  }

  void _insertFormula(bool isBlock) {
    final TextEditingController formulaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBlock ? '插入公式块' : '插入行内公式'),
        content: TextField(
          controller: formulaController,
          decoration: const InputDecoration(
            hintText: '例如: E = mc^2',
            border: OutlineInputBorder(),
          ),
          maxLines: isBlock ? 3 : 1,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final formulaData = {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'latex': formulaController.text,
                'block': isBlock,
              };

              final selection = _controller.selection;
              _controller.replaceText(
                selection.start,
                selection.extentOffset - selection.start,
                flutter_quill.BlockEmbed.custom(flutter_quill.CustomBlockEmbed(
                    'formula', jsonEncode(formulaData))),
                TextSelection.collapsed(offset: selection.start + 1),
              );

              _quillFocusNode.requestFocus();
              Navigator.pop(context);
            },
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }

  void _insertCodeBlock() {
    final TextEditingController codeController = TextEditingController();
    String selectedLanguage = 'dart';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('插入代码块'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'dart', child: Text('Dart')),
                    DropdownMenuItem(
                        value: 'javascript', child: Text('JavaScript')),
                    DropdownMenuItem(value: 'python', child: Text('Python')),
                    DropdownMenuItem(value: 'java', child: Text('Java')),
                    DropdownMenuItem(value: 'cpp', child: Text('C++')),
                    DropdownMenuItem(value: 'html', child: Text('HTML')),
                    DropdownMenuItem(value: 'css', child: Text('CSS')),
                    DropdownMenuItem(value: 'json', child: Text('JSON')),
                    DropdownMenuItem(
                        value: 'plaintext', child: Text('Plain Text')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    hintText: '输入代码...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 10,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final codeData = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'code': codeController.text,
                    'language': selectedLanguage,
                  };

                  final selection = _controller.selection;
                  _controller.replaceText(
                    selection.start,
                    selection.extentOffset - selection.start,
                    flutter_quill.BlockEmbed.custom(
                        flutter_quill.CustomBlockEmbed(
                            'code-block', jsonEncode(codeData))),
                    TextSelection.collapsed(offset: selection.start + 1),
                  );

                  _quillFocusNode.requestFocus();
                  Navigator.pop(context);
                },
                child: const Text('插入'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _insertDrawing() {
    final drawingId =
        'new_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1000)}';
    final drawingData = {
      'id': drawingId,
      'points': [],
      'height': 300.0,
    };
    final selection = _controller.selection;
    debugPrint(
        'MinimalJournalEditor._insertDrawing: INSERTING drawing at ${selection.start} with ID $drawingId');
    debugPrint('Insert StackTrace:\n${StackTrace.current}');
    _controller.replaceText(
      selection.start,
      selection.extentOffset - selection.start,
      flutter_quill.BlockEmbed.custom(
          flutter_quill.CustomBlockEmbed('drawing', jsonEncode(drawingData))),
      TextSelection.collapsed(offset: selection.start + 1),
    );

    _quillFocusNode.requestFocus();
  }

  void _showStyleBottomSheet() {
    // Style sheet implementation
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('样式',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepSpaceGray)),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 20, color: AppTheme.deepSpaceGray),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Simple style controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                          icon: const Text('B',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.bold);
                          }),
                      IconButton(
                          icon: const Text('I',
                              style: TextStyle(fontStyle: FontStyle.italic)),
                          onPressed: () {
                            _controller.formatSelection(
                                flutter_quill.Attribute.italic);
                          }),
                      IconButton(
                          icon: const Text('U',
                              style: TextStyle(
                                  decoration: TextDecoration.underline)),
                          onPressed: () {
                            _controller.formatSelection(
                                flutter_quill.Attribute.underline);
                          }),
                      IconButton(
                          icon: const Text('S',
                              style: TextStyle(
                                  decoration: TextDecoration.lineThrough)),
                          onPressed: () {
                            _controller.formatSelection(
                                flutter_quill.Attribute.strikeThrough);
                          }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                          icon: const Text('H1'),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.h1);
                          }),
                      IconButton(
                          icon: const Text('H2'),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.h2);
                          }),
                      IconButton(
                          icon: const Text('H3'),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.h3);
                          }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Lists
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.ul);
                          }),
                      IconButton(
                          icon: const Icon(Icons.format_list_numbered),
                          onPressed: () {
                            _controller
                                .formatSelection(flutter_quill.Attribute.ol);
                          }),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 显示颜色选择器对话框
  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择画笔颜色',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // 常用颜色选项
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var color in [
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.purple,
                  Colors.orange,
                  Colors.pink,
                  Colors.teal,
                  Colors.grey,
                  Colors.brown,
                  Colors.cyan,
                ])
                  GestureDetector(
                    onTap: () {
                      _brushColorNotifier.value = color;
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.mediumGray),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示画笔粗细调整滑块
  void _showBrushWidthSlider() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isEraser = _isEraserModeNotifier.value;
          double currentWidth =
              isEraser ? _eraserWidthNotifier.value : _brushWidthNotifier.value;
          return ExcludeSemantics(
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEraser ? '调整橡皮擦大小' : '调整画笔粗细',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _SimpleWidthSlider(
                      value: currentWidth,
                      min: 1.0,
                      max: 50.0,
                      onChanged: (value) {
                        setModalState(() {
                          currentWidth = value;
                        });

                        // 同步更新 ValueNotifier
                        if (isEraser) {
                          _eraserWidthNotifier.value = value;
                        } else {
                          _brushWidthNotifier.value = value;
                        }
                      },
                      onChangeEnd: () {
                        // 延迟关闭以确保状态稳定
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${currentWidth.toStringAsFixed(1)}px',
                            style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 显示背景选项菜单
  void _showBackgroundOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择背景样式',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // 透明背景
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBackgroundType = BackgroundType.transparent;
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.mediumGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.clear, size: 40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('透明'),
                    ],
                  ),
                ),
                // 网格背景
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBackgroundType = BackgroundType.grid;
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.mediumGray),
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image:
                                AssetImage('assets/images/grid_background.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('网格'),
                    ],
                  ),
                ),
                // 横线背景
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBackgroundType = BackgroundType.lines;
                      _showHorizontalLinesNotifier.value = true;
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.mediumGray),
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: AssetImage(
                                'assets/images/lines_background.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('横线'),
                    ],
                  ),
                ),
                // 纯色背景
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBackgroundType = BackgroundType.solid;
                      _solidBackgroundColor = AppTheme.offWhite;
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          border: Border.all(color: AppTheme.mediumGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('纯色'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.draw),
                title: const Text('绘图'),
                onTap: () {
                  _insertDrawing();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('音频'),
                onTap: () {
                  _insertAudio();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('视频'),
                onTap: () {
                  _insertVideo();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('更多文件'),
                onTap: () {
                  _insertMoreFiles();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInsertMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('插入内容',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calculate),
                title: const Text('行内公式'),
                onTap: () {
                  Navigator.pop(context);
                  _insertFormula(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calculate),
                title: const Text('公式块'),
                onTap: () {
                  Navigator.pop(context);
                  _insertFormula(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('插入代码块'),
                onTap: () {
                  Navigator.pop(context);
                  _insertCodeBlock();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reparent the focus attachment to ensure focus works correctly
    _focusAttachment.reparent();

    return Scaffold(
      backgroundColor: _solidBackgroundColor,
      appBar: AppBar(
        backgroundColor: _solidBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.deepSpaceGray),
          onPressed: widget.onCancel,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.undo, color: AppTheme.deepSpaceGray),
            onPressed: () => _controller.undo(),
          ),
          IconButton(
            icon: Icon(Icons.redo, color: AppTheme.deepSpaceGray),
            onPressed: () => _controller.redo(),
          ),
          IconButton(
            icon: Icon(Icons.check,
                color: _hasChanges
                    ? AppTheme.primaryColor
                    : AppTheme.lightSurfaceGray),
            onPressed: _hasChanges ? _saveJournal : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ExcludeSemantics(
              excluding: _isDrawingMode,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '标题',
                        hintStyle: TextStyle(
                            fontSize: 24,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.lightSurfaceGray
                                    : AppTheme.darkGray,
                            fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.offWhite
                              : AppTheme.deepSpaceGray),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '今天 ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.lightSurfaceGray
                                  : AppTheme.darkGray),
                        ),
                        const SizedBox(width: 8),
                        BlocBuilder<CategoryBloc, CategoryState>(
                          builder: (context, categoryState) {
                            List<Category> categories = [];

                            // Handle different category states
                            if (categoryState is CategoryLoaded) {
                              categories = categoryState.categories
                                  .where(
                                      (cat) => cat.type == CategoryType.journal)
                                  .toList();
                            } else if (categoryState is CategoryInitial ||
                                categoryState is CategoryLoading) {
                              // Show default category or loading indicator
                              return const SizedBox.shrink();
                            } else if (categoryState is CategoryError) {
                              // Handle error state
                              return const SizedBox.shrink();
                            }

                            // If no categories available, create a default one
                            if (categories.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final validCategoryId =
                                categories.any((cat) => cat.id == _categoryId)
                                    ? _categoryId
                                    : categories.first.id;
                            final selectedCategory = categories
                                .firstWhere((cat) => cat.id == validCategoryId);

                            return PopupMenuButton<String>(
                              position: PopupMenuPosition.under,
                              initialValue: validCategoryId,
                              onSelected: (value) {
                                setState(() {
                                  _categoryId = value;
                                });
                              },
                              child: Row(
                                children: [
                                  Text(selectedCategory.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.darkGray)),
                                  Icon(Icons.arrow_drop_down,
                                      size: 16, color: AppTheme.darkGray),
                                ],
                              ),
                              itemBuilder: (context) =>
                                  categories.map((category) {
                                return PopupMenuItem(
                                  value: category.id,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(category.name),
                                      if (category.id == validCategoryId)
                                        Icon(Icons.check,
                                            color: AppTheme.primaryColor,
                                            size: 16),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              // 关键：在绘图模式下，彻底隔离整个编辑区域的语义，防止 Windows Accessibility Bridge 崩溃
              child: ExcludeSemantics(
                excluding: _isDrawingMode,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. 文字层和已保存的绘图内容 - 一起滚动
                    SingleChildScrollView(
                      controller: _pageScrollController,
                      // 允许在绘图模式下也能滚动
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.transparent,
                        // 确保Container有最小高度，即使没有内容也能绘图
                        constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height - 200),
                        child: Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            // 文字编辑器 - 位于底层
                            flutter_quill.QuillEditor.basic(
                              controller: _controller,
                              focusNode: _quillFocusNode,
                              config: flutter_quill.QuillEditorConfig(
                                autoFocus: true,
                                scrollable: false,
                                padding: EdgeInsets.zero,
                                placeholder: '开始记录你的想法...',
                                checkBoxReadOnly: _isDrawingMode,
                                embedBuilders: [
                                  // 只使用自定义嵌入构建器，避免与 flutter_quill_extensions 冲突
                                  CustomImageEmbedBuilder(),
                                  DrawingEmbedBuilder(),
                                  CheckboxEmbedBuilder(_handleCheckboxToggle),
                                  AudioEmbedBuilder(),
                                  CustomVideoEmbedBuilder(
                                      readOnly: _isDrawingMode),
                                  FileEmbedBuilder(),
                                  FormulaEmbedBuilder(),
                                  CodeBlockEmbedBuilder(),
                                  CustomEmbedBuilder(_handleCheckboxToggle),
                                  UnknownEmbedBuilder(),
                                ],
                              ),
                            ),
                            // 已保存的绘图内容 - 优化：在绘图模式下不显示背景层，因为 Overlay 层已经绘制了这些点
                            if (!_isDrawingMode)
                              ValueListenableBuilder<List<DrawingPoint>>(
                                valueListenable: _drawingPointsNotifier,
                                builder: (context, points, child) {
                                  if (points.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return RepaintBoundary(
                                    child: IgnorePointer(
                                      ignoring: true, // 总是忽略，因为在非绘图模式下也是静态展示
                                      child: CustomPaint(
                                        painter: _DrawingContentPainter(points),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            // 水平横线背景 - 根据 _showHorizontalLinesNotifier.value 状态显示（仅在绘图模式下）
                            if (_isDrawingMode &&
                                _showHorizontalLinesNotifier.value)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _HorizontalLinesPainter(),
                                  size: Size.infinite,
                                ),
                              ),
                            // 绘图覆盖层 - 只在绘图模式下显示，与文字内容在同一个坐标系中
                            // 关键：将SimpleDrawingOverlay放在文字层之上，并与文字层一起滚动
                            // 从而彻底解决橡皮擦坐标偏移和保存后点位发生位移的问题
                            if (_isDrawingMode)
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: SimpleDrawingOverlay(
                                    key: _drawingOverlayKey,
                                    isDrawingMode: _isDrawingMode,
                                    initialDrawingPoints:
                                        _drawingPointsNotifier.value,
                                    onDrawingUpdated: (points) {
                                      if (!_isDisposed && mounted) {
                                        _drawingPointsNotifier.value = points;
                                      }
                                    },
                                    onExitDrawingMode: () {
                                      _safeToggleDrawingMode();
                                    },
                                    scrollController: _pageScrollController,
                                    brushColorNotifier: _brushColorNotifier,
                                    brushWidthNotifier: _brushWidthNotifier,
                                    eraserWidthNotifier: _eraserWidthNotifier,
                                    isEraserModeNotifier: _isEraserModeNotifier,
                                    showHorizontalLinesNotifier:
                                        _showHorizontalLinesNotifier,
                                    backgroundType: _currentBackgroundType,
                                    backgroundColor: _solidBackgroundColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部工具栏
            if (!_showStylePanel)
              _isDrawingMode
                  ? ExcludeSemantics(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color: AppTheme.mediumGray, width: 0.5))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // 1. 完成并保存
                            IconButton(
                              icon: Icon(Icons.keyboard,
                                  size: 24, color: AppTheme.secondaryColor),
                              onPressed: () {
                                if (_isDisposed) return;
                                _safeToggleDrawingMode();
                              },
                              tooltip:
                                  null, // 移除 Tooltip 以防止 Windows Accessibility 崩溃
                            ),
                            // 2. 画笔颜色选择图标
                            IconButton(
                              icon: Icon(Icons.palette,
                                  size: 24, color: AppTheme.accentColor),
                              onPressed: _showColorPicker,
                              tooltip: null,
                            ),
                            // 3. 画笔粗细选择图标
                            ValueListenableBuilder<bool>(
                              valueListenable: _isEraserModeNotifier,
                              builder: (context, isEraser, child) {
                                return IconButton(
                                  icon: const Icon(Icons.brush, size: 24),
                                  color: isEraser
                                      ? AppTheme.deepSpaceGray
                                      : AppTheme.accentColor,
                                  onPressed: () {
                                    // 强制切换到画笔模式并弹出粗细选择
                                    _isEraserModeNotifier.value = false;
                                    _showBrushWidthSlider();
                                  },
                                  tooltip: null,
                                );
                              },
                            ),
                            // 4. 橡皮擦
                            ValueListenableBuilder<bool>(
                              valueListenable: _isEraserModeNotifier,
                              builder: (context, isEraser, child) {
                                return GestureDetector(
                                  onLongPress: () {
                                    // 长按弹出粗细选择器，强制设为橡皮擦模式以显示正确标题
                                    _isEraserModeNotifier.value = true;
                                    _showBrushWidthSlider();
                                  },
                                  child: IconButton(
                                    icon: Icon(
                                        isEraser
                                            ? Icons.cleaning_services
                                            : Icons.cleaning_services_outlined,
                                        size: 24,
                                        color: isEraser
                                            ? AppTheme.errorColor
                                            : AppTheme.deepSpaceGray),
                                    onPressed: () {
                                      if (isEraser) {
                                        // 如果已经是橡皮擦模式，点击则弹出大小选择
                                        _showBrushWidthSlider();
                                      } else {
                                        // 否则进入橡皮擦模式
                                        _isEraserModeNotifier.value = true;
                                      }
                                    },
                                    tooltip: null,
                                  ),
                                );
                              },
                            ),
                            // 5. 插入复选框图标
                            IconButton(
                              icon: Icon(Icons.check_box_outlined,
                                  size: 24, color: AppTheme.deepSpaceGray),
                              onPressed: () {
                                final selection = _controller.selection;
                                final checkboxId = DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString();
                                final checkboxData = jsonEncode(
                                    {'id': checkboxId, 'checked': false});
                                _controller.replaceText(
                                    selection.start,
                                    selection.extentOffset - selection.start,
                                    flutter_quill.BlockEmbed.custom(
                                        flutter_quill.CustomBlockEmbed(
                                            'checkbox', checkboxData)),
                                    TextSelection.collapsed(
                                        offset: selection.start + 1));
                              },
                              tooltip: null,
                            ),
                            // 6. 清空画布
                            IconButton(
                              icon: Icon(Icons.delete_sweep_outlined,
                                  size: 24, color: AppTheme.errorColor),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('清空画布'),
                                    content: const Text('确定要清空所有绘图轨迹吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _drawingPointsNotifier.value = [];
                                          Navigator.pop(context);
                                        },
                                        child: Text('清空',
                                            style: TextStyle(
                                                color: AppTheme.errorColor)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              tooltip: null,
                            ),
                            // 7. 插入附件图标
                            IconButton(
                              icon: Icon(Icons.add_circle_outline,
                                  size: 24, color: AppTheme.deepSpaceGray),
                              onPressed: _showAttachmentMenu,
                              tooltip: null,
                            ),
                            // 8. 录音图标
                            IconButton(
                              icon: Icon(
                                  _isRecording
                                      ? Icons.stop
                                      : Icons.mic_outlined,
                                  size: 24,
                                  color: _isRecording
                                      ? AppTheme.errorColor
                                      : AppTheme.deepSpaceGray),
                              onPressed: () {
                                if (_isRecording) {
                                  _stopRecording();
                                } else {
                                  _startRecording();
                                }
                              },
                              tooltip: null,
                            ),
                            // 9. 背景切换图标
                            IconButton(
                              icon: Icon(Icons.wallpaper,
                                  size: 24, color: AppTheme.deepSpaceGray),
                              onPressed: _showBackgroundOptions,
                              tooltip: null,
                            ),
                            // 10. 背景是否显示横线图标
                            ValueListenableBuilder<bool>(
                              valueListenable: _showHorizontalLinesNotifier,
                              builder: (context, showLines, child) {
                                return IconButton(
                                  icon: Icon(Icons.format_line_spacing,
                                      size: 24,
                                      color: showLines
                                          ? AppTheme.accentColor
                                          : AppTheme.deepSpaceGray),
                                  onPressed: () {
                                    _showHorizontalLinesNotifier.value =
                                        !showLines;
                                  },
                                  tooltip: null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      height: 56,
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: AppTheme.mediumGray, width: 0.5))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: Icon(Icons.draw,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: () {
                              if (_isDisposed) return;
                              _safeToggleDrawingMode();
                            },
                            tooltip: '进入绘图模式',
                          ),
                          IconButton(
                            icon: Icon(Icons.check_box_outlined,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: () {
                              final selection = _controller.selection;
                              final checkboxId = DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();
                              final checkboxData = jsonEncode(
                                  {'id': checkboxId, 'checked': false});
                              _controller.replaceText(
                                  selection.start,
                                  selection.extentOffset - selection.start,
                                  flutter_quill.BlockEmbed.custom(
                                      flutter_quill.CustomBlockEmbed(
                                          'checkbox', checkboxData)),
                                  TextSelection.collapsed(
                                      offset: selection.start + 1));
                            },
                            tooltip: '插入复选框',
                          ),
                          IconButton(
                            icon: Icon(Icons.format_size,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: _showStyleBottomSheet,
                            tooltip: '样式设置',
                          ),
                          IconButton(
                            icon: Icon(Icons.code,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: _showInsertMenu,
                            tooltip: '插入公式/代码',
                          ),
                          IconButton(
                            icon: Icon(Icons.image_outlined,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: _insertImage,
                            tooltip: '插入图片',
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline,
                                size: 24, color: AppTheme.deepSpaceGray),
                            onPressed: _showAttachmentMenu,
                            tooltip: '添加附件',
                          ),
                          IconButton(
                            icon: Icon(
                                _isRecording ? Icons.stop : Icons.mic_outlined,
                                size: 24,
                                color: _isRecording
                                    ? AppTheme.errorColor
                                    : AppTheme.deepSpaceGray),
                            onPressed: () {
                              if (_isRecording) {
                                _stopRecording();
                              } else {
                                _startRecording();
                              }
                            },
                            tooltip: _isRecording ? '停止录音' : '开始录音',
                          ),
                        ],
                      ),
                    )
          ],
        ),
      ),
    );
  }
}

/// Painter specifically for drawing content, isolated from other UI elements
class _DrawingContentPainter extends CustomPainter {
  final List<DrawingPoint> points;

  _DrawingContentPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    Path? currentPath;
    Color? lastColor;
    double? lastWidth;

    // 直接遍历原列表，限制最大绘制数量但不进行内存拷贝
    final int limit = points.length > 5000 ? 5000 : points.length;

    for (int i = 0; i < limit; i++) {
      final point = points[i];

      final offset = point.offset;
      if (!offset.dx.isFinite || !offset.dy.isFinite) continue;

      // 如果样式发生变化，先绘制之前的路径并重置
      if (currentPath == null ||
          point.color != lastColor ||
          point.width != lastWidth) {
        if (currentPath != null) {
          paint.color = lastColor ?? AppTheme.deepSpaceGray;
          paint.strokeWidth = lastWidth ?? 3.0;
          canvas.drawPath(currentPath, paint);
        }
        currentPath = Path();
        currentPath.moveTo(offset.dx, offset.dy);
        lastColor = point.color;
        lastWidth = point.width;
      } else {
        currentPath.lineTo(offset.dx, offset.dy);
      }

      // 如果是一笔的结束，立即绘制
      if (point.isEndOfStroke || i == limit - 1) {
        paint.color = lastColor ?? AppTheme.deepSpaceGray;
        paint.strokeWidth = lastWidth ?? 3.0;
        canvas.drawPath(currentPath, paint);
        currentPath = null;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingContentPainter oldDelegate) {
    if (identical(oldDelegate.points, points)) return false;
    if (oldDelegate.points.length != points.length) return true;

    // 如果点数很少，直接比较所有点
    if (points.length <= 20) {
      for (int i = 0; i < points.length; i++) {
        final oldPoint = oldDelegate.points[i];
        final newPoint = points[i];
        if (oldPoint.offset != newPoint.offset ||
            oldPoint.isEndOfStroke != newPoint.isEndOfStroke) {
          return true;
        }
      }
      return false;
    }

    // 对于大量点，只比较最后10个点以提高性能
    final compareCount = 10;
    final startIndex = points.length - compareCount;

    for (int i = startIndex; i < points.length; i++) {
      final oldPoint = oldDelegate.points[i];
      final newPoint = points[i];
      if (oldPoint.offset != newPoint.offset ||
          oldPoint.isEndOfStroke != newPoint.isEndOfStroke) {
        return true;
      }
    }

    return false;
  }
}

/// 自定义轻量级滑块，避免使用原生 Slider 导致的 Windows Accessibility 崩溃问题
class _SimpleWidthSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeEnd;

  const _SimpleWidthSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double progress = ((value - min) / (max - min)).clamp(0.0, 1.0);
        // 计算滑块位置，减去滑块自身一半宽度以居中
        final double knobPosition = (progress * width).clamp(0.0, width) - 10;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final double localX = details.localPosition.dx.clamp(0.0, width);
            final double percent = (localX / width).clamp(0.0, 1.0);
            onChanged(min + (max - min) * percent);
          },
          onHorizontalDragEnd: (_) => onChangeEnd?.call(),
          onTapDown: (details) {
            final double localX = details.localPosition.dx.clamp(0.0, width);
            final double percent = (localX / width).clamp(0.0, 1.0);
            onChanged(min + (max - min) * percent);
          },
          onTapUp: (_) => onChangeEnd?.call(),
          child: Container(
            height: 48,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 轨道 (Track)
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 激活轨道 (Active Track)
                Container(
                  height: 6,
                  width: progress * width,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // 滑块 (Knob)
                Positioned(
                  left: knobPosition,
                  top: -7,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepSpaceGray.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
