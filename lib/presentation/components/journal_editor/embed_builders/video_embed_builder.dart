import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_package;
import 'package:video_player/video_player.dart';
import '../video_width_manager.dart';

// 自定义视频嵌入构建器
class CustomVideoEmbedBuilder extends EmbedBuilder {
  final bool readOnly;

  CustomVideoEmbedBuilder({this.readOnly = false});

  @override
  String get key => 'video';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final nodeValue = embedContext.node.value.data;
    String videoPath = '';
    double? width;

    if (nodeValue is String) {
      try {
        // 尝试解析JSON字符串，兼容旧数据格式
        final map = jsonDecode(nodeValue);
        if (map is Map) {
          videoPath = map['path'] ?? '';
          width = map['width']?.toDouble();
        } else {
          // 如果解析失败或不是map，直接使用字符串作为路径
          videoPath = nodeValue;
        }
      } catch (e) {
        // JSON解析失败，直接使用字符串作为路径
        videoPath = nodeValue;
      }
    } else if (nodeValue is Map) {
      // 处理map类型数据
      if (nodeValue.containsKey('path')) {
        videoPath = nodeValue['path'] ?? '';
        width = nodeValue['width']?.toDouble();
      } else {
        // 尝试查找可能的视频路径键
        final possibleKeys = ['video', 'url', 'file', 'name'];
        for (final key in possibleKeys) {
          if (nodeValue.containsKey(key)) {
            videoPath = nodeValue[key]?.toString() ?? '';
            break;
          }
        }
      }
    }

    return VideoPlayerWidget(
      key: ValueKey(videoPath),
      videoPath: videoPath,
      initialWidth: width,
      readOnly: readOnly,
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  final double? initialWidth;
  final bool readOnly;

  const VideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.initialWidth,
    this.readOnly = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

/// 视频组件的实际实现，包含状态管理
class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _hasError = false;
  late double _widthFactor;
  bool _showScrollbar = false;
  Timer? _resizeDebounce;
  bool _isUpdating = false;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _widthFactor = widget.initialWidth ?? 1.0;
    // Fix for legacy data where width might be absolute (e.g. 300.0)
    if (_widthFactor < 0.2 || _widthFactor > 1.0) {
      _widthFactor = 1.0;
    }
    // 初始显示滚动条
    _showScrollbar = true;

    // 初始化视频控制器
    _initializeVideoController();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoPath != oldWidget.videoPath) {
      _disposeController();
      _initializeVideoController();
    }
    // Handle ReadOnly toggle
    if (widget.readOnly != oldWidget.readOnly) {
      if (widget.readOnly) {
        // Entered drawing mode -> Pause video to stop texture updates
        _controller?.pause();
      }
      // Force rebuild to possibly swap UI if needed (though pause is usually enough)
      if (mounted) setState(() {});
    }
  }

  void _toggleScrollbar() {
    setState(() {
      _showScrollbar = !_showScrollbar;
    });
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      /* 
         On Windows, disposing a video player that is still "busy" or posting messages
         can cause "Failed to post message to main thread" crashes.
         We remove the listener first.
      */
      controller.removeListener(_videoListener);
      await controller.dispose();
    }
  }

  // 初始化视频控制器，添加错误处理
  Future<void> _initializeVideoController() async {
    if (_isDisposed) return;

    // Slight delay to allow previous frame to clear if rapid rebuilding
    await Future.delayed(const Duration(milliseconds: 200));
    if (_isDisposed) return;

    try {
      VideoPlayerController? newController;
      String videoPath = widget.videoPath;
      
      // 尝试创建视频控制器
      if (kIsWeb) {
        // Web平台，使用网络URL
        if (!videoPath.startsWith('http://') && !videoPath.startsWith('https://')) {
          // 检查视频路径是否有效，避免尝试加载无效的URL
          if (videoPath.isNotEmpty && !videoPath.contains('VideoPlayerWidget')) {
            // 如果是相对路径且有效，尝试通过服务器访问
            videoPath = 'http://localhost:5000/uploads/$videoPath';
          } else {
            // 无效的视频路径，抛出错误
            throw Exception('Invalid video path: $videoPath');
          }
        }
        newController = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        // 桌面平台，处理本地文件路径
        File videoFile;
        
        // 检查是否是完整路径
        if (File(videoPath).existsSync()) {
          videoFile = File(videoPath);
        } else {
          // 尝试从应用文档目录查找
          final appDir = await getApplicationDocumentsDirectory();
          final storageDir = Directory(path_package.join(appDir.path, 'MomentKeep'));
          final videoDir = Directory(path_package.join(storageDir.path, 'videos'));
          
          // 尝试完整路径
          final fullPath = path_package.join(videoDir.path, videoPath);
          videoFile = File(fullPath);
          
          if (!videoFile.existsSync()) {
            // 尝试其他可能的路径
            final alternativePath = path_package.join(storageDir.path, videoPath);
            videoFile = File(alternativePath);
          }
        }
        
        if (!videoFile.existsSync()) {
          debugPrint('Video file not found: ${widget.videoPath}, tried: ${videoFile.path}');
          if (mounted) setState(() => _hasError = true);
          return;
        }
        
        newController = VideoPlayerController.file(videoFile.absolute);
      }

      if (_isDisposed) {
        newController.dispose();
        return;
      }

      _controller = newController;

      // 监听初始化完成事件
      await _controller?.initialize();

      if (_isDisposed) {
        _disposeController();
        return;
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      // 监听视频状态变化
      _controller?.addListener(_videoListener);
    } catch (e) {
      debugPrint('Video controller creation error: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (mounted && !_isDisposed && _controller != null) {
      final isPlaying = _controller!.value.isPlaying;
      if (isPlaying != _wasPlaying) {
        _wasPlaying = isPlaying;
        setState(() {
          // 视频播放时隐藏滚动条，暂停或停止时显示滚动条
          _showScrollbar = !isPlaying;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resizeDebounce?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _handleResizeEnd(double value) {
    // Cancel any pending resize
    _resizeDebounce?.cancel();

    // Prevent concurrent updates
    if (_isUpdating) {
      debugPrint('Video resize: Update already in progress, skipping');
      return;
    }

    // Debounce the resize to prevent rapid updates
    _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isUpdating) {
        _isUpdating = true;
        try {
          // Store width in global manager - will be saved when journal is saved
          VideoWidthManager().setWidth(widget.videoPath, value);
          debugPrint('[Video] Stored width $value for ${widget.videoPath}');
        } finally {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _isUpdating = false;
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 如果初始化失败或发生错误，显示占位符
    if (_hasError || !_isInitialized || _controller == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final currentWidth = maxWidth * _widthFactor;

          return Center(
            child: SizedBox(
              width: currentWidth,
              child: GestureDetector(
                onTap: _toggleScrollbar,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 显示占位符
                    Container(
                      height: 200,
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library,
                                color: Colors.white, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              '视频: ${widget.videoPath.split('/').last}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '视频播放功能在当前平台上暂不支持',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 显示调整大小控件，仅在需要时显示
                    if (_showScrollbar) Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_size_select_large,
                                color: Colors.white, size: 16),
                            SizedBox(
                              width: 100,
                              height: 20,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10),
                                  trackHeight: 2,
                                ),
                                child: Slider(
                                  value: _widthFactor,
                                  min: 0.2,
                                  max: 1.0,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                  onChanged: (val) {
                                    setState(() {
                                      _widthFactor = val;
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    _handleResizeEnd(val);
                                  },
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
          );
        },
      );
    }

    // 正常显示视频播放器
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final currentWidth = maxWidth * _widthFactor;

        return Center(
          child: SizedBox(
            width: currentWidth,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 视频播放器
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
                // 播放/暂停控制和点击切换滚动条
    GestureDetector(
      onTap: () {
        setState(() {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
          // 点击视频时始终显示滚动条，而不是切换
          _showScrollbar = true;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity: !_controller!.value.isPlaying
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    ),
                // 进度条
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: !_controller!.value.isPlaying
                        ? 1.0
                        : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                  ),
                ),
                // 显示调整大小控件，仅在需要时显示
                if (_showScrollbar) Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_size_select_large,
                            color: Colors.white, size: 16),
                        SizedBox(
                          width: 100,
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: _widthFactor,
                              min: 0.2,
                              max: 1.0,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white30,
                              onChanged: (val) {
                                setState(() {
                                  _widthFactor = val;
                                });
                              },
                              onChangeEnd: (val) {
                                _handleResizeEnd(val);
                              },
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
        );
      },
    );
  }
}
