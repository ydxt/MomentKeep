import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 音频录制和播放服务
class AudioRecordingService {
  /// 单例实例
  static final AudioRecordingService _instance =
      AudioRecordingService._internal();

  /// 音频播放器
  AudioPlayer? _player;

  /// 音频录制器
  final AudioRecorder _recorder = AudioRecorder();

  /// 当前播放的音频文件路径
  String? _currentPlayingAudioPath;

  /// 当前播放状态
  bool _isPlaying = false;

  /// 音频时长（秒）
  Duration _audioDuration = Duration.zero;

  /// 当前录音路径
  String? _currentRecordingPath;

  /// 录音开始时间
  DateTime? _recordingStartTime;

  /// 播放完成回调
  final StreamController<void> _onPlaybackCompleteController =
      StreamController<void>.broadcast();

  /// 播放器是否已初始化
  bool _isPlayerInitialized = false;

  /// 获取播放完成流
  Stream<void> get onPlaybackComplete => _onPlaybackCompleteController.stream;

  /// 私有构造函数
  AudioRecordingService._internal() {
    // 初始化音频播放器
    _player = AudioPlayer();
    _isPlayerInitialized = true;
  }

  /// 工厂构造函数
  factory AudioRecordingService() => _instance;

  /// 检查设备是否支持录音
  Future<bool> checkPermission() async {
    try {
      // 使用record库检查录音权限
      return await _recorder.hasPermission();
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  /// 开始录音
  Future<String?> startRecording() async {
    try {
      // 检查权限
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        print('No permission to record audio');
        return null;
      }

      // 获取存储路径
      Directory storageDir;
      Directory momentkeepDir;
      Directory audioDir;

      // 从SharedPreferences获取自定义存储路径
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('storage_path');

      if (customPath != null && customPath.isNotEmpty) {
        // 使用自定义存储路径
        storageDir = Directory(customPath);
      } else {
        // 使用默认路径
        storageDir = await getApplicationDocumentsDirectory();
      }

      // 创建MomentKeep目录，与StorageService保持一致
      momentkeepDir = Directory('${storageDir.path}/MomentKeep');

      // 创建audio子目录
      audioDir = Directory('${momentkeepDir.path}/audio');

      // 确保存储目录存在
      if (!await momentkeepDir.exists()) {
        await momentkeepDir.create(recursive: true);
      }

      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // 必须确保文件名以 .m4a 结尾，因为默认编码是 AAC
      final filePath =
          '${audioDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // 记录录音开始时间
      _recordingStartTime = DateTime.now();
      _currentRecordingPath = filePath;

      // 开始录音，指定Windows支持的编码
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      print('开始录音，文件路径：$filePath');
      print('正在录音，文件保存至: $filePath');

      return filePath;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  /// 停止录音
  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      if (_currentRecordingPath != null && _recordingStartTime != null) {
        // 计算录音时长
        final duration = DateTime.now().difference(_recordingStartTime!);

        // 停止录音
        await _recorder.stop();

        final path = _currentRecordingPath;

        // 打印调试信息
        print('停止录音，文件路径：$path');

        // 验证文件是否存在
        final file = File(path!);
        final fileExists = await file.exists();
        print('文件是否存在：$fileExists');

        // 获取文件大小
        final size = await file.length();
        print('文件大小：$size 字节');

        // 打印录音文件路径，方便用户查看
        print('录音文件已生成，路径：$path');
        print('录音时长：$duration');
        print('文件大小：$size 字节');

        return {
          'path': path,
          'duration': duration,
          'size': size,
        };
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  /// 播放音频
  Future<void> playAudio(String audioPath) async {
    try {
      print('Starting to play audio: $audioPath');

      // 检查播放器是否已初始化
      if (!_isPlayerInitialized || _player == null) {
        print('Audio player not initialized, initializing now...');
        _player = AudioPlayer();
        _isPlayerInitialized = true;
      }

      // 如果正在播放其他音频，先停止
      if (_isPlaying && _currentPlayingAudioPath != audioPath) {
        print('Stopping current audio before playing new one');
        await stopAudio();
      }

      _currentPlayingAudioPath = audioPath;

      // 获取音频时长
      print('Getting audio duration for: $audioPath');
      _audioDuration = await getAudioDuration(audioPath);
      print('Audio duration: $_audioDuration');

      _isPlaying = true;
      print('Set playing state to true');

      // 检查是否为项目中的音频资源
      if (audioPath.startsWith('audio/')) {
        try {
          // 播放项目中的音频资源
          print('Playing project audio asset: $audioPath');
          // 对于项目中的音频资源，我们需要使用正确的路径格式
          // AssetSource会自动添加'assets/'前缀，所以我们需要保留'audio/'前缀
          // 最终路径会是：assets/audio/alarm_sound.mp3
          await _player!.play(AssetSource(audioPath));
          print('Successfully started playing audio asset: $audioPath');

          // 监听播放完成
          print('Setting up playback complete listener');
          _player!.onPlayerComplete.listen((_) {
            print('Playback completed for: $audioPath');
            if (_isPlaying && _currentPlayingAudioPath == audioPath) {
              _isPlaying = false;
              if (!_onPlaybackCompleteController.isClosed) {
                _onPlaybackCompleteController.add(null);
              }
              print('Set playing state to false after completion');
            }
          });
        } catch (e) {
          print('Error playing audio asset: $e');
          // 实际播放失败时，回退到模拟播放
          _simulatePlayback(audioPath);
        }
      } else {
        // 检查文件是否存在且不为空
        final file = File(audioPath);
        final fileExists = await file.exists();
        final fileSize = fileExists ? await file.length() : 0;

        print(
            'Checking file: $audioPath, exists: $fileExists, size: $fileSize');

        if (fileExists && fileSize > 0) {
          try {
            // 播放设备上的音频文件
            print('Playing device file: $audioPath');
            // 先设置源，再播放
            await _player!.setSource(DeviceFileSource(audioPath));
            await _player!.resume();
            print('Successfully started playing device file: $audioPath');

            // 监听播放完成
            print('Setting up playback complete listener');
            _player!.onPlayerComplete.listen((_) {
              print('Playback completed for: $audioPath');
              if (_isPlaying && _currentPlayingAudioPath == audioPath) {
                _isPlaying = false;
                if (!_onPlaybackCompleteController.isClosed) {
                  _onPlaybackCompleteController.add(null);
                }
                print('Set playing state to false after completion');
              }
            });
          } catch (e) {
            print('Error playing device file: $e');
            // 实际播放失败时，回退到模拟播放
            _simulatePlayback(audioPath);
          }
        } else {
          // 文件不存在或为空，回退到模拟播放
          print('File not found or empty, simulating playback: $audioPath');
          _simulatePlayback(audioPath);
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      // 即使播放失败，也要确保状态正确
      _isPlaying = false;
      print('Set playing state to false due to error');
    }
  }

  /// 模拟音频播放
  void _simulatePlayback(String audioPath) {
    // 模拟播放完成
    Future.delayed(_audioDuration, () {
      if (_isPlaying && _currentPlayingAudioPath == audioPath) {
        _isPlaying = false;
        // 检查控制器是否已关闭，避免添加事件到已关闭的控制器
        if (!_onPlaybackCompleteController.isClosed) {
          _onPlaybackCompleteController.add(null);
        }
      }
    });
  }

  /// 暂停音频
  Future<void> pauseAudio() async {
    try {
      if (_isPlayerInitialized && _player != null) {
        await _player!.pause();
        _isPlaying = false;
      }
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  /// 恢复播放
  Future<void> resumeAudio() async {
    try {
      if (_isPlayerInitialized &&
          _player != null &&
          _currentPlayingAudioPath != null) {
        await _player!.resume();
        _isPlaying = true;
      }
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  /// 停止音频
  Future<void> stopAudio() async {
    try {
      if (_isPlayerInitialized && _player != null) {
        await _player!.stop();
      }
      _isPlaying = false;
      _currentPlayingAudioPath = null;
    } catch (e) {
      print('Error stopping audio: $e');
      // 即使停止失败，也要确保状态正确
      _isPlaying = false;
      _currentPlayingAudioPath = null;
    }
  }

  /// 获取当前播放状态
  bool get isPlaying => _isPlaying;

  /// 获取当前播放的音频路径
  String? get currentPlayingAudioPath => _currentPlayingAudioPath;

  /// 获取音频时长
  Duration get audioDuration => _audioDuration;

  /// 获取音频时长格式化字符串（mm:ss）
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 获取指定音频文件的时长
  Future<Duration> getAudioDuration(String audioPath) async {
    try {
      // 检查是否为项目中的音频资源
      if (audioPath.startsWith('audio/')) {
        // 检查播放器是否已初始化
        if (!_isPlayerInitialized || _player == null) {
          print('Audio player not initialized, initializing now...');
          _player = AudioPlayer();
          _isPlayerInitialized = true;
        }
        // 对于项目中的音频资源，使用AssetSource获取时长
        // AssetSource会自动添加'assets/'前缀，所以我们需要保留'audio/'前缀
        // 最终路径会是：assets/audio/alarm_sound.mp3
        await _player!.setSource(AssetSource(audioPath));
        final duration = await _player!.getDuration();
        return duration ?? Duration(seconds: 5);
      } else {
        // 检查文件是否存在且不为空
        final file = File(audioPath);
        final fileExists = await file.exists();
        final fileSize = fileExists ? await file.length() : 0;

        if (fileExists && fileSize > 0) {
          // 对于真实文件，直接返回基于文件大小的估算时长
          // 假设平均比特率为128kbps，1秒约16KB
          final estimatedDuration =
              Duration(seconds: (fileSize / 16384).ceil());
          return estimatedDuration > Duration.zero
              ? estimatedDuration
              : Duration(seconds: 5);
        } else {
          // 对于模拟文件或空文件，返回默认时长
          return Duration(seconds: 5);
        }
      }
    } catch (e) {
      print('Error getting audio duration: $e');
      // 出错时返回默认时长
      return Duration(seconds: 5);
    }
  }

  /// 删除音频文件
  Future<bool> deleteAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        // 如果正在播放该音频，先停止
        if (_currentPlayingAudioPath == audioPath) {
          await stopAudio();
        }
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting audio: $e');
      return false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      if (_isPlayerInitialized && _player != null) {
        await _player!.dispose();
        _player = null;
        _isPlayerInitialized = false;
      }
      await _onPlaybackCompleteController.close();
    } catch (e) {
      print('Error disposing audio service: $e');
      // 确保资源状态正确
      _player = null;
      _isPlayerInitialized = false;
    }
  }
}
