import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moment_keep/core/services/audio_recording_service.dart';

/// 音频消息组件（类似微信语音样式）
class AudioMessageWidget extends StatefulWidget {
  /// 音频文件路径
  final String audioPath;

  /// 音频时长（秒）
  final Duration duration;

  /// 是否为发送方（右侧显示，不同背景色）
  final bool isSender;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 多选回调
  final VoidCallback? onMultiSelect;

  /// 转文字回调
  final VoidCallback? onTranscribe;

  /// 引用回调
  final VoidCallback? onQuote;

  /// 提醒回调
  final VoidCallback? onRemind;

  /// 插入内容回调
  final VoidCallback? onInsertContent;

  const AudioMessageWidget({
    super.key,
    required this.audioPath,
    required this.duration,
    this.isSender = false,
    this.onDelete,
    this.onMultiSelect,
    this.onTranscribe,
    this.onQuote,
    this.onRemind,
    this.onInsertContent,
  });

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioRecordingService _audioService = AudioRecordingService();
  bool _isPlaying = false;
  StreamSubscription? _playbackCompleteSubscription;

  @override
  void initState() {
    super.initState();

    // 监听播放完成事件
    _playbackCompleteSubscription =
        _audioService.onPlaybackComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackCompleteSubscription?.cancel();
    // 停止播放并释放资源
    _audioService.stopAudio();
    super.dispose();
  }

  /// 格式化时长为 mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 处理音频播放/暂停
  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioService.pauseAudio();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });

      try {
        await _audioService.playAudio(widget.audioPath);

        // For mock files, simulate playback complete after a short delay
        // This ensures the play icon resets even with mock files
        Future.delayed(widget.duration, () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      } catch (e) {
        print('Error playing audio: $e');
        // If playback fails, reset the icon immediately
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    }
  }

  /// 显示长按菜单
  void _showLongPressMenu(LongPressStartDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final screenSize = overlay.size;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx - 10,
        details.globalPosition.dy - 10,
        screenSize.width - details.globalPosition.dx + 10,
        screenSize.height - details.globalPosition.dy + 10,
      ),
      items: [
        if (widget.onDelete != null)
          PopupMenuItem(
            value: 'delete',
            onTap: widget.onDelete,
            child: const Row(
              children: [
                Icon(Icons.delete, size: 16),
                SizedBox(width: 8),
                Text('删除'),
              ],
            ),
          ),
        if (widget.onMultiSelect != null)
          PopupMenuItem(
            value: 'multiSelect',
            onTap: widget.onMultiSelect,
            child: const Row(
              children: [
                Icon(Icons.select_all, size: 16),
                SizedBox(width: 8),
                Text('多选'),
              ],
            ),
          ),
        if (widget.onTranscribe != null)
          PopupMenuItem(
            value: 'transcribe',
            onTap: widget.onTranscribe,
            child: const Row(
              children: [
                Icon(Icons.voice_chat, size: 16),
                SizedBox(width: 8),
                Text('转文字'),
              ],
            ),
          ),
        if (widget.onQuote != null)
          PopupMenuItem(
            value: 'quote',
            onTap: widget.onQuote,
            child: const Row(
              children: [
                Icon(Icons.format_quote, size: 16),
                SizedBox(width: 8),
                Text('引用'),
              ],
            ),
          ),
        if (widget.onRemind != null)
          PopupMenuItem(
            value: 'remind',
            onTap: widget.onRemind,
            child: const Row(
              children: [
                Icon(Icons.alarm, size: 16),
                SizedBox(width: 8),
                Text('提醒'),
              ],
            ),
          ),
        if (widget.onInsertContent != null)
          PopupMenuItem(
            value: 'insertContent',
            onTap: widget.onInsertContent,
            child: const Row(
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: 8),
                Text('插入内容'),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayback,
      onLongPressStart: _showLongPressMenu,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isSender
              ? const Color(0xFFDCF8C6)
              : const Color(0xFFECECEC),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: widget.isSender
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: widget.isSender
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放/暂停图标
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isPlaying ? 0.5 : 0,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isSender ? Colors.black87 : Colors.black54,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // 音频波形指示器（简化版）
            Row(
              children: List.generate(5, (index) {
                final height = _isPlaying
                    ? (index % 2 == 0 ? 20.0 : 12.0)
                    : (index + 1) * 3.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: widget.isSender ? Colors.black87 : Colors.black54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(width: 12),

            // 时长显示
            Text(
              _formatDuration(widget.duration),
              style: TextStyle(
                fontSize: 14,
                color: widget.isSender ? Colors.black87 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
