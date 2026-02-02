import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'editor_controller.dart';
import '../../components/audio_message_widget.dart';

class BlockEditor extends StatefulWidget {
  final EditorController controller;
  final bool isQuestionBank;

  const BlockEditor({
    super.key,
    required this.controller,
    this.isQuestionBank = false,
  });

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  // 用于存储视频控制器，确保每个视频块只有一个控制器实例
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void dispose() {
    // 释放所有视频控制器资源
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final blocks = widget.controller.blocks;

        // 清理不再使用的视频控制器
        _cleanupVideoControllers(blocks);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isQuestionBank) _buildQuestionBankHeader(),
              if (blocks.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('暂无内容'),
                      const SizedBox(height: 16),
                      GestureDetector(
                      onTapDown: (details) {
                        _showInsertMenu(0, details.globalPosition);
                      },
                      child: ElevatedButton.icon(
                        onPressed: () {}, // Empty onPressed to ensure gesture is recognized
                        icon: const Icon(Icons.add),
                        label: const Text('添加内容'),
                      ),
                    ),
                    ],
                  ),
                )
              else
                for (int index = 0; index < blocks.length; index++)
                  _buildBlockItem(blocks[index], index),
            ],
          ),
        );
      },
    );
  }

  /// 清理不再使用的视频控制器
  void _cleanupVideoControllers(List<ContentBlock> currentBlocks) {
    // 获取当前所有视频块的ID
    final currentVideoBlockIds = currentBlocks
        .where((block) => block.type == ContentBlockType.video)
        .map((block) => block.id)
        .toSet();

    // 找出需要移除的控制器
    final controllersToRemove = _videoControllers.keys
        .where((id) => !currentVideoBlockIds.contains(id))
        .toList();

    // 移除并释放控制器
    for (final id in controllersToRemove) {
      _videoControllers[id]?.dispose();
      _videoControllers.remove(id);
    }
  }

  Widget _buildQuestionBankHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: '科目',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            labelText: '备注',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBlockItem(ContentBlock block, int index) {
    switch (block.type) {
      case ContentBlockType.text:
        return _buildTextBlock(block);
      case ContentBlockType.image:
        return _buildImageBlock(block);
      case ContentBlockType.audio:
        return _buildAudioBlock(block);
      case ContentBlockType.drawing:
        // Return an empty container for drawing blocks since this editor doesn't support drawing
        return const SizedBox(height: 40);
      case ContentBlockType.video:
        return _buildVideoBlock(block);
    }
  }

  Widget _buildTextBlock(ContentBlock block) {
    final controller = widget.controller.getTextController(block.id);
    final focusNode = widget.controller.getFocusNode(block.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plus button for inserting media - always visible
          GestureDetector(
            onTapDown: (details) {
              // Get exact tap position
              _showInsertMenu(block.orderIndex + 1, details.globalPosition);
            },
            onTap: () {
              // Empty onTap to ensure gesture is recognized
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.add_circle_outline,
                color: Colors.grey,
                size: 24,
              ),
            ),
            behavior: HitTestBehavior.opaque,
          ),

          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (event) {
                if (event is RawKeyDownEvent) {
                  if (event.logicalKey.keyLabel == 'Enter') {
                    widget.controller.handleEnter(block.id);
                  } else if (event.logicalKey.keyLabel == 'Backspace') {
                    if (controller?.text.isEmpty ?? true) {
                      widget.controller.handleBackspace(block.id);
                    }
                  }
                }
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '输入文本...',
                ),
                onChanged: (text) =>
                    widget.controller.updateText(block.id, text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBlock(ContentBlock block) {
    final blockIndex = widget.controller.blocks.indexOf(block);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 图片缩略图显示
            GestureDetector(
              // 点击图片放大显示
              onTap: () {
                _showMediaViewer(block.data, ContentBlockType.image);
              },
              // 右键点击显示菜单
              onSecondaryTapDown: (details) {
                _showBlockMenu(block, blockIndex, details.globalPosition);
              },
              // 长按显示菜单
              onLongPressStart: (details) {
                _showBlockMenu(block, blockIndex, details.globalPosition);
              },
              child: _buildImageWidget(block.data),
            ),
            // 删除按钮
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () async {
                  try {
                    await widget.controller.removeBlockById(block.id);
                  } catch (e) {
                    debugPrint('Failed to remove block: $e');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建视频块（缩略图显示，点击播放）
  Widget _buildVideoBlock(ContentBlock block) {
    final blockIndex = widget.controller.blocks.indexOf(block);
    final durationSeconds = block.attributes['duration'] as int? ?? 0;
    final duration = Duration(seconds: durationSeconds);
    final formattedDuration = '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    // 确保每个视频块只有一个控制器实例
    if (!_videoControllers.containsKey(block.id)) {
      _videoControllers[block.id] = VideoPlayerController.file(File(block.data));
      // 初始化控制器
      _videoControllers[block.id]?.initialize().then((_) {
        // 初始化完成后暂停，只显示第一帧
        _videoControllers[block.id]?.pause();
        setState(() {}); // 触发重绘
      }).catchError((e) {
        debugPrint('Error initializing video controller for block ${block.id}: $e');
      });
    }

    final controller = _videoControllers[block.id];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 视频缩略图 - 固定高度200px，与图片保持一致
            GestureDetector(
              // 点击视频放大显示
              onTap: () {
                _showMediaViewer(block.data, ContentBlockType.video);
              },
              // 右键点击显示菜单
              onSecondaryTapDown: (details) {
                _showBlockMenu(block, blockIndex, details.globalPosition);
              },
              // 长按显示菜单
              onLongPressStart: (details) {
                _showBlockMenu(block, blockIndex, details.globalPosition);
              },
              child: Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey.shade200,
                child: Stack(
                  children: [
                    if (controller != null && controller.value.isInitialized)
                      // 视频第一帧，固定高度，显示完整内容
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    else
                      // 加载中或初始化失败时显示占位符
                      const Center(child: CircularProgressIndicator()),
                    // 播放按钮覆盖层
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    // 右下角显示时长
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 删除按钮
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () async {
                  try {
                    await widget.controller.removeBlockById(block.id);
                  } catch (e) {
                    debugPrint('Failed to remove block: $e');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 初始化视频控制器，用于获取缩略图
  Future<VideoPlayerController?> _initializeVideoController(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      // 暂停视频，只显示第一帧
      await controller.pause();
      return controller;
    } catch (e) {
      debugPrint('Error initializing video controller for thumbnail: $e');
      return null;
    }
  }

  /// 显示块操作菜单
  void _showBlockMenu(ContentBlock block, int blockIndex, Offset globalPosition) {
    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;
    final screenSize = overlay.size;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx - 10,
        globalPosition.dy - 10,
        screenSize.width - globalPosition.dx + 10,
        screenSize.height - globalPosition.dy + 10,
      ),
      items: [
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete, size: 16),
              SizedBox(width: 8),
              Text('删除'),
            ],
          ),
          onTap: () async {
            try {
              await widget.controller.removeBlockById(block.id);
            } catch (e) {
              debugPrint('Failed to remove block: $e');
            }
          },
        ),
        PopupMenuItem(
          value: 'insertContent',
          child: const Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('插入内容'),
            ],
          ),
          onTap: () => _showInsertMenu(blockIndex + 1, globalPosition),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String imageData) {
    // 取消原地缩放功能，改为点击图片最大化显示
    return _buildBaseImage(imageData);
  }

  Widget _buildBaseImage(String imageData) {
    // Check if it's a web blob URL or network URL
    if (imageData.startsWith('blob:') || imageData.startsWith('http')) {
      return Image.network(
        imageData,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('图片加载失败'),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: 200,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else {
      // For mobile, load from file system
      return FutureBuilder<String>(
        future: _getFullPath(imageData),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.file(
              File(snapshot.data!),
              fit: BoxFit.contain,
              width: double.infinity,
              height: 200,
            );
          }
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
  }

  Widget _buildAudioBlock(ContentBlock block) {
    // Get audio duration from attributes or default to 0
    final durationInSeconds = block.attributes['duration'] as int? ?? 0;
    final duration = Duration(seconds: durationInSeconds);
    final blockIndex = widget.controller.blocks.indexOf(block);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          AudioMessageWidget(
            audioPath: block.data,
            duration: duration,
            isSender: true,
            onDelete: () async {
              try {
                await widget.controller.removeBlockById(block.id);
              } catch (e) {
                debugPrint('Failed to remove audio block: $e');
              }
            },
            onMultiSelect: () {
              debugPrint('Multi-select audio block: ${block.id}');
            },
            onTranscribe: () {
              debugPrint('Transcribe audio block: ${block.id}');
            },
            onQuote: () {
              debugPrint('Quote audio block: ${block.id}');
            },
            onRemind: () {
              debugPrint('Remind audio block: ${block.id}');
            },
            onInsertContent: () {
              _showInsertMenu(blockIndex + 1);
            },
          ),
          // 删除按钮，与图片块的删除按钮样式保持一致
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () async {
                try {
                  await widget.controller.removeBlockById(block.id);
                } catch (e) {
                  debugPrint('Failed to remove audio block: $e');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getFullPath(String path) async {
    // 如果已经是绝对路径，直接返回
    if (path.startsWith('/') || path.contains(':')) {
      return path;
    }
    // 否则，将相对路径转换为绝对路径
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$path';
  }

  void _showInsertMenu(int index, [Offset? position]) {
    // Check if the previous block is an empty text block
    bool isPreviousBlockEmptyText = false;
    int actualInsertIndex = index;

    // Only check previous block if index > 0 and blocks list is not empty
    if (index > 0 && widget.controller.blocks.isNotEmpty && index - 1 < widget.controller.blocks.length) {
      final prevBlock = widget.controller.blocks[index - 1];
      if (prevBlock.type == ContentBlockType.text) {
        final controller = widget.controller.getTextController(prevBlock.id);
        if (controller != null && controller.text.isEmpty) {
          isPreviousBlockEmptyText = true;
          actualInsertIndex = index - 1;
        }
      }
    }

    // Create menu items
        final menuItems = [
          PopupMenuItem(
            value: 'text',
            child: const Row(
              children: [
                Icon(Icons.text_fields, size: 16),
                SizedBox(width: 8),
                Text('插入文本框'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'image',
            child: const Row(
              children: [
                Icon(Icons.image, size: 16),
                SizedBox(width: 8),
                Text('插入图片'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'video',
            child: const Row(
              children: [
                Icon(Icons.videocam, size: 16),
                SizedBox(width: 8),
                Text('插入视频'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'record_video',
            child: const Row(
              children: [
                Icon(Icons.videocam_off, size: 16),
                SizedBox(width: 8),
                Text('录制视频'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'record',
            child: const Row(
              children: [
                Icon(Icons.mic, size: 16),
                SizedBox(width: 8),
                Text('录制音频'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'import',
            child: const Row(
              children: [
                Icon(Icons.audio_file, size: 16),
                SizedBox(width: 8),
                Text('导入音频'),
              ],
            ),
          ),
        ];

    // Show menu at position if provided, otherwise use bottom sheet
    if (position != null) {
      // Calculate menu position based on tap location
      final double buttonSize = 40.0;
      
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx - buttonSize / 2,
          position.dy - buttonSize / 2,
          position.dx + buttonSize / 2,
          position.dy + buttonSize / 2,
        ),
        items: menuItems,
      ).then((value) async {
        if (value != null) {
          await _handleInsertMenuSelection(value, actualInsertIndex, isPreviousBlockEmptyText);
        }
      });
    } else {
      // For the initial empty state, still use bottom sheet
      showModalBottomSheet(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: menuItems,
        ),
      ).then((value) async {
        if (value != null) {
          await _handleInsertMenuSelection(value, actualInsertIndex, isPreviousBlockEmptyText);
        }
      });
    }
  }

  /// Handle insert menu selection
  Future<void> _handleInsertMenuSelection(dynamic value, int actualInsertIndex, bool isPreviousBlockEmptyText) async {
    // 如果是文本块，直接插入并返回
    if (value == 'text') {
      widget.controller.addTextBlock(index: actualInsertIndex);
      return;
    }

    // 如果前一个块是空文本块，先保存它的ID，以便稍后删除
    String? emptyTextBlockId;
    if (isPreviousBlockEmptyText && widget.controller.blocks.isNotEmpty && actualInsertIndex < widget.controller.blocks.length) {
      emptyTextBlockId = widget.controller.blocks[actualInsertIndex].id;
    }

    // 插入媒体块
    switch (value) {
      case 'image':
        await widget.controller.addImageBlock(actualInsertIndex);
        break;
      case 'video':
        await widget.controller.addVideoBlock(actualInsertIndex);
        break;
      case 'record_video':
        await widget.controller.recordVideoBlock(actualInsertIndex);
        break;
      case 'record':
        _showRecordingDialog(actualInsertIndex);
        break;
      case 'import':
        await widget.controller.importAudioBlock(actualInsertIndex);
        break;
    }

    // 如果媒体块插入成功，在媒体块下方插入一个新的空文本块
    // 插入位置是实际插入位置 + 1（因为媒体块已经插入到actualInsertIndex位置）
    widget.controller.addTextBlock(index: actualInsertIndex + 1);

    // 如果前一个块是空文本块，删除它
    if (emptyTextBlockId != null) {
      try {
        await widget.controller.removeBlockById(emptyTextBlockId);
      } catch (e) {
        debugPrint('Failed to remove empty text block: $e');
      }
    }
  }

  /// 显示全屏图片
  /// 显示媒体查看器（支持图片和视频）
  void _showMediaViewer(String mediaPath, ContentBlockType mediaType) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _MediaViewerDialog(
        mediaPath: mediaPath,
        mediaType: mediaType,
      ),
    );
  }

  void _showRecordingDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordingDialog(
        controller: widget.controller,
        index: index,
      ),
    );
  }
}

class _RecordingDialog extends StatefulWidget {
  final EditorController controller;
  final int index;

  const _RecordingDialog({
    required this.controller,
    required this.index,
  });

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    await widget.controller.recordAudioBlock(widget.index);
    setState(() {
      _isRecording = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await widget.controller.stopRecordingAndAddBlock(widget.index);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('录制音频'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mic,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_isRecording)
            const Text(
              '录制中...',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _stopRecording,
          child: const Text('停止并保存'),
        ),
      ],
    );
  }
}

/// 媒体查看器对话框（支持图片和视频）
class _MediaViewerDialog extends StatefulWidget {
  final String mediaPath;
  final ContentBlockType mediaType;

  const _MediaViewerDialog({
    required this.mediaPath,
    required this.mediaType,
  });

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  double _scale = 1.0;
  final TransformationController _transformationController = TransformationController();
  Offset _focusPoint = Offset.zero;
  bool _hasFocusPoint = false;
  // 视频相关状态
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == ContentBlockType.video) {
      _initializeVideoController();
    }
  }

  @override
  void dispose() {
    if (widget.mediaType == ContentBlockType.video && _videoController != null) {
      _videoController!.dispose();
    }
    super.dispose();
  }

  /// 初始化视频控制器
  Future<void> _initializeVideoController() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.mediaPath));
      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 点击空白区域关闭
      onTap: () {
        Navigator.pop(context);
      },
      child: Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // 媒体内容显示
            Center(
              child: widget.mediaType == ContentBlockType.image
                  ? _buildImageViewer()
                  : _buildVideoPlayer(),
            ),

            // 关闭按钮
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建图片查看器
  Widget _buildImageViewer() {
    return GestureDetector(
      // 记录点击位置
      onTapDown: (details) {
        setState(() {
          _focusPoint = details.localPosition;
          _hasFocusPoint = true;
        });
      },
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        transformationController: _transformationController,
        onInteractionEnd: (details) {
          // Update scale when user finishes interacting
          final currentScale = _transformationController.value.getMaxScaleOnAxis();
          setState(() {
            _scale = currentScale;
          });
        },
        child: _buildFullScreenImage(),
      ),
    );
  }

  /// 构建视频播放器
  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _videoController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return GestureDetector(
      // 点击播放/暂停
      onTap: () {
        setState(() {
          if (_isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
          _isPlaying = !_isPlaying;
        });
      },
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_videoController!),
            // 播放/暂停按钮
            if (!_isPlaying)
              Center(
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _videoController!.play();
                      _isPlaying = true;
                    });
                  },
                ),
              ),
            // 视频控制栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建全屏显示的图片
  Widget _buildFullScreenImage() {
    if (widget.mediaPath.startsWith('blob:') || widget.mediaPath.startsWith('http')) {
      return Image.network(
        widget.mediaPath,
        fit: BoxFit.contain,
        height: double.infinity,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('图片加载失败', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return FutureBuilder<String>(
        future: _getFullPath(widget.mediaPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.file(
              File(snapshot.data!),
              fit: BoxFit.contain,
              height: double.infinity,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('图片加载失败', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
      );
    }
  }

  /// 获取完整路径
  Future<String> _getFullPath(String path) async {
    // 如果已经是绝对路径，直接返回
    if (path.startsWith('/') || path.contains(':')) {
      return path;
    }
    // 否则，将相对路径转换为绝对路径
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$path';
  }
}
