import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/services/audio_recording_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';
import 'package:moment_keep/services/database_service.dart';

class EditorController extends ChangeNotifier {
  final List<ContentBlock> _blocks = [];
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();
  final AudioRecordingService _audioService = AudioRecordingService();
  final StorageService _storageService = StorageService();
  String? _currentRecordingPath;

  List<ContentBlock> get blocks => List.unmodifiable(_blocks);

  EditorController({List<ContentBlock>? initialBlocks}) {
    if (initialBlocks != null && initialBlocks.isNotEmpty) {
      _blocks.addAll(initialBlocks);
      for (var block in _blocks) {
        if (block.type == ContentBlockType.text) {
          _textControllers[block.id] = TextEditingController(text: block.data);
          _focusNodes[block.id] = FocusNode();
        }
      }
    }
    // 如果没有初始内容，不要自动添加空的text block
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    _audioService.dispose();
    super.dispose();
  }

  /// 添加文本块
  void addTextBlock({required int index, String text = ''}) {
    _addTextBlock(index: index, text: text);
  }

  void _addTextBlock({required int index, String text = ''}) {
    final id = _uuid.v4();
    final block = ContentBlock(
      id: id,
      type: ContentBlockType.text,
      data: text,
      orderIndex: index,
    );
    _blocks.insert(index, block);
    _textControllers[id] = TextEditingController(text: text);
    _focusNodes[id] = FocusNode();
    notifyListeners();
  }

  void updateText(String id, String text) {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      _blocks[index] = _blocks[index].copyWith(data: text);
      notifyListeners(); // 通知监听器内容已改变
    }
  }

  void handleEnter(String currentBlockId) {
    final index = _blocks.indexWhere((b) => b.id == currentBlockId);
    if (index != -1) {
      final newIndex = index + 1;
      _addTextBlock(index: newIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[_blocks[newIndex].id]?.requestFocus();
      });
    }
  }

  void handleBackspace(String currentBlockId) {
    final index = _blocks.indexWhere((b) => b.id == currentBlockId);
    if (index > 0) {
      final currentBlock = _blocks[index];
      if (currentBlock.type == ContentBlockType.text &&
          currentBlock.data.isEmpty) {
        // Check if this is the last text block and adjacent to non-text block
        bool isLastTextBlock = true;
        for (int i = index + 1; i < _blocks.length; i++) {
          if (_blocks[i].type == ContentBlockType.text) {
            isLastTextBlock = false;
            break;
          }
        }

        // Check if previous block is non-text
        bool prevBlockIsNonText =
            _blocks[index - 1].type != ContentBlockType.text;

        // Don't delete if it's the last text block and adjacent to non-text block
        if (!(isLastTextBlock && prevBlockIsNonText)) {
          _removeBlock(index);
          final prevBlock = _blocks[index - 1];
          if (prevBlock.type == ContentBlockType.text) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusNodes[prevBlock.id]?.requestFocus();
              final controller = _textControllers[prevBlock.id];
              if (controller != null) {
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
            });
          }
        }
      }
    }
  }

  Future<void> _removeBlock(int index) async {
    final block = _blocks[index];
    
    // 删除相关文件
    if (block.type == ContentBlockType.image || 
        block.type == ContentBlockType.audio ||
        block.type == ContentBlockType.video) {
      try {
        await _storageService.deleteFile(block.data);
      } catch (e) {
        // 即使文件删除失败，也继续删除块
      }
    }
    
    _blocks.removeAt(index);
    _textControllers[block.id]?.dispose();
    _textControllers.remove(block.id);
    _focusNodes[block.id]?.dispose();
    _focusNodes.remove(block.id);
    notifyListeners();
  }

  Future<void> removeBlockById(String id) async {
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index != -1) {
      await _removeBlock(index);
    }
  }

  Future<void> addImageBlock(int index) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final id = _uuid.v4();

        // For web, store the blob URL directly
        // For mobile/desktop, save to app directory using StorageService
        String imageData;
        final databaseService = DatabaseService();
        final userId = await databaseService.getCurrentUserId() ?? 'default_user';

        if (kIsWeb) {
          imageData = image.path; // This is a blob URL on web
        } else {
          // 使用StorageService存储图片，确保图片存储在MomentKeep目录内部
          imageData = await _storageService.storeImage(image, userId: userId);
        }

        final block = ContentBlock(
          id: id,
          type: ContentBlockType.image,
          data: imageData,
          orderIndex: index,
        );
        _blocks.insert(index, block);
        notifyListeners();

        // Check if there's already a text block after, if not, add one
        if (index + 1 >= _blocks.length ||
            _blocks[index + 1].type != ContentBlockType.text) {
          _addTextBlock(index: index + 1);
        }
      }
    } catch (e) {
      debugPrint('Error adding image block: $e');
    }
  }

  Future<void> addVideoBlock(int index) async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _processVideo(video, index);
      }
    } catch (e) {
      debugPrint('Error adding video block: $e');
    }
  }

  /// 录制视频并添加到编辑器
  Future<void> recordVideoBlock(int index) async {
    try {
      // 检查平台，Windows平台上ImagePicker的相机功能支持有限
      if (defaultTargetPlatform == TargetPlatform.windows) {
        debugPrint('Video recording from camera is not supported on Windows platform');
        return;
      }
      
      // 录制视频，使用默认设置
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
      );
      if (video != null) {
        await _processVideo(video, index);
      }
    } catch (e) {
      debugPrint('Error recording video: $e');
    }
  }

  /// 处理视频文件，存储并添加到编辑器
  Future<void> _processVideo(XFile video, int index) async {
    final id = _uuid.v4();

    // For web, store the blob URL directly
    // For mobile/desktop, save to app directory using StorageService
    String videoData;
    final databaseService = DatabaseService();
    final userId = await databaseService.getCurrentUserId() ?? 'default_user';

    if (kIsWeb) {
      videoData = video.path; // This is a blob URL on web
    } else {
      // 使用StorageService存储视频，确保视频存储在MomentKeep目录内部
      videoData = await _storageService.storeVideo(video, userId: userId);
    }

    // 获取视频时长
    Duration duration = Duration.zero;
    try {
      final videoController = VideoPlayerController.file(File(videoData));
      await videoController.initialize();
      duration = videoController.value.duration;
      await videoController.dispose();
    } catch (e) {
      debugPrint('Error getting video duration: $e');
    }

    final block = ContentBlock(
      id: id,
      type: ContentBlockType.video,
      data: videoData,
      orderIndex: index,
      attributes: {
        'duration': duration.inSeconds,
      },
    );
    _blocks.insert(index, block);
    notifyListeners();

    // Check if there's already a text block after, if not, add one
    if (index + 1 >= _blocks.length ||
        _blocks[index + 1].type != ContentBlockType.text) {
      _addTextBlock(index: index + 1);
    }
  }

  Future<void> recordAudioBlock(int index) async {
    try {
      final path = await _audioService.startRecording();
      if (path != null) {
        _currentRecordingPath = path;
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> stopRecordingAndAddBlock(int index) async {
    try {
      final result = await _audioService.stopRecording();
      if (result != null) {
        final audioPath = result['path'] as String;
        final duration = result['duration'] as Duration;

        // 使用真实的录音文件
        final id = _uuid.v4();
        final block = ContentBlock(
          id: id,
          type: ContentBlockType.audio,
          data: audioPath, // 使用真实的录音文件路径
          orderIndex: index,
          attributes: {
            'duration': duration.inSeconds,
          },
        );
        _blocks.insert(index, block);
        notifyListeners();

        // Check if there's already a text block after, if not, add one
        if (index + 1 >= _blocks.length ||
            _blocks[index + 1].type != ContentBlockType.text) {
          _addTextBlock(index: index + 1);
        }
      }
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
    }
  }

  Future<void> importAudioBlock(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;
        String audioPath;
        final databaseService = DatabaseService();
        final userId = await databaseService.getCurrentUserId() ?? 'default_user';

        // For all platforms, use StorageService to save the audio file
        if (file.path != null) {
          // Save to app directory using StorageService
          final xFile = XFile(file.path!);
          audioPath = await _storageService.storeAudio(xFile, userId: userId);
        } else {
          return;
        }

        final id = _uuid.v4();

        // 获取真实音频时长，支持所有平台
        Duration duration;
        try {
          duration = await _audioService.getAudioDuration(audioPath);
        } catch (e) {
          // 如果获取失败，使用默认时长
          duration = Duration(seconds: 10);
        }

        final block = ContentBlock(
          id: id,
          type: ContentBlockType.audio,
          data: audioPath,
          orderIndex: index,
          attributes: {
            'duration': duration.inSeconds,
          },
        );
        _blocks.insert(index, block);
        notifyListeners();

        // Check if there's already a text block after, if not, add one
        if (index + 1 >= _blocks.length ||
            _blocks[index + 1].type != ContentBlockType.text) {
          _addTextBlock(index: index + 1);
        }
      }
    } catch (e) {
      debugPrint('Error importing audio: $e');
    }
  }

  TextEditingController? getTextController(String id) => _textControllers[id];
  FocusNode? getFocusNode(String id) => _focusNodes[id];
}
