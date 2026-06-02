import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

// 自定义音频嵌入构建器
class AudioEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final nodeData = embedContext.node.value.data;
    String audioPath = '';
    String audioName = '';

    // Parse audio data - can be either a simple string or JSON object
    if (nodeData is String) {
      try {
        final map = jsonDecode(nodeData);
        if (map is Map) {
          audioPath = map['path'] ?? '';
          audioName = map['name'] ?? '';
        } else {
          audioPath = nodeData;
        }
      } catch (e) {
        // Not JSON, treat as plain path
        audioPath = nodeData;
      }
    } else if (nodeData is Map) {
      audioPath = nodeData['path'] ?? '';
      audioName = nodeData['name'] ?? '';
    }

    return AudioPlayerWidget(
      key: ValueKey(audioPath),
      audioPath: audioPath,
      audioName: audioName.isNotEmpty
          ? audioName
          : audioPath.split('/').last.split('\\').last,
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final String audioName;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.audioName = '',
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isDisposed = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // 确保所有音频播放器事件都在UI线程上处理
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;

      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (!_isDisposed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              setState(() {
                _isPlaying = state == PlayerState.playing;
              });
            }
          });
        }
      });

      _audioPlayer.onDurationChanged.listen((newDuration) {
        if (!_isDisposed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              setState(() {
                _duration = newDuration;
              });
            }
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((newPosition) {
        if (!_isDisposed) {
          // Only update if difference is meaningful (e.g. > 500ms) to avoid high fps rebuilds
          if ((newPosition - _position).abs().inMilliseconds > 500) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _position = newPosition;
                });
              }
            });
          }
        }
      });
    });

    // Initialize audio source with improved error handling and state management
    Future.microtask(() async {
      if (_isDisposed) return;

      // 更安全的延迟初始化，避免与UI渲染冲突
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isDisposed) return;

      try {
        if (kIsWeb) {
          // On web, build full URL if path is not already a URL
          String audioUrl = widget.audioPath;
          if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
            // Build full URL using server address
            audioUrl = 'http://localhost:5000/uploads/$audioUrl';
          }
          await _audioPlayer.setSourceUrl(audioUrl);
        } else {
          if (!File(widget.audioPath).existsSync()) {
            debugPrint('Audio file not found: ${widget.audioPath}');
            return;
          }
          await _audioPlayer.setSourceDeviceFile(widget.audioPath);
        }

        if (!_isDisposed) {
          final d = await _audioPlayer.getDuration();
          if (d != null && mounted && !_isDisposed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isDisposed) {
                setState(() => _duration = d);
              }
            });
          }
        }
      } catch (e, stack) {
        debugPrint('Error initializing audio: $e');
        debugPrint('Stack trace: $stack');
      }
    });
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    _isDisposed = true;
    try {
      // 更安全的资源释放
      // 1. 尝试暂停播放
      try {
        await _audioPlayer.pause();
      } catch (e) {
        debugPrint('Error pausing audio: $e');
      }

      // 2. 延迟释放资源，避免与其他操作冲突
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. 释放播放器
      await _audioPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.audioName.isNotEmpty
        ? widget.audioName
        : widget.audioPath.split('/').last.split('\\').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20), // Rounded rectangle
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled),
            color: Colors.blue,
            iconSize: 32,
            onPressed: () async {
              try {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  // 检查文件是否存在
                  if (!kIsWeb && !File(widget.audioPath).existsSync()) {
                    debugPrint('Audio file not found: ${widget.audioPath}');
                    return;
                  }

                  // 确保播放器状态正确
                  if (_isDisposed) return;

                  // 构建完整URL
                  String audioUrl = widget.audioPath;
                  if (kIsWeb && (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://'))) {
                    // 构建完整URL
                    audioUrl = 'http://localhost:5000/uploads/$audioUrl';
                  }
                  // 使用正确的播放源
                  final source = kIsWeb
                      ? UrlSource(audioUrl)
                      : DeviceFileSource(widget.audioPath);

                  await _audioPlayer.play(source);
                }
              } catch (e) {
                debugPrint('Audio play/pause error: $e');
                // 重置播放状态
                if (mounted && !_isDisposed) {
                  setState(() {
                    _isPlaying = false;
                  });
                }
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble(),
                          min: 0,
                          max: _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0,
                          onChanged: (value) async {
                            try {
                              if (_isDisposed) return;
                              final position = Duration(seconds: value.toInt());
                              await _audioPlayer.seek(position);
                            } catch (e) {
                              debugPrint('Audio seek error: $e');
                            }
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
