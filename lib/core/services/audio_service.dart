import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// 音频类型枚举
enum AudioType {
  notification,
  alarm,
  bell,
  chime,
  cuteNotification,
  churchBell,
}

/// 音频服务类，用于管理应用中的音频播放
class AudioService {
  /// 单例实例
  static final AudioService _instance = AudioService._internal();

  /// 音频播放器实例列表 - 跟踪所有活跃的播放器
  List<AudioPlayer> _audioPlayers = [];

  /// 音频文件路径映射
  final Map<AudioType, String> _audioPaths = {
    AudioType.notification: 'notification_sound.mp3',
    AudioType.alarm: 'alarm_sound.mp3',
    AudioType.bell: 'bell_sound.mp3',
    AudioType.chime: 'chime_sound.mp3',
    AudioType.cuteNotification: 'cute notification sounds.mp3',
    AudioType.churchBell: 'BELLLrg_Church bell.wav',
  };

  /// 私有构造函数
  AudioService._internal() {
    // 确保Flutter绑定已初始化
    WidgetsFlutterBinding.ensureInitialized();
    print('AudioService initialized');
  }

  /// 工厂构造函数
  factory AudioService() => _instance;

  /// 播放指定类型的音频
  Future<void> playSound(AudioType audioType) async {
    try {
      final String fileName = _audioPaths[audioType]!;
      print('Attempting to play sound: $fileName');
      
      // 直接使用文件名，因为音频文件在assets/audio目录中
      final assetSource = AssetSource('audio/$fileName');
      print('AssetSource created: ${assetSource.path}');
      
      // 创建新的音频播放器实例
      final player = AudioPlayer();
      _audioPlayers.add(player);
      print('Created new AudioPlayer instance, total players: ${_audioPlayers.length}');
      
      // 播放音频
      await player.play(assetSource);
      print('Play called successfully');

      print('Sound played successfully: $fileName');
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  /// 停止所有当前播放的音频
  Future<void> stopSound() async {
    try {
      print('Attempting to stop all sounds, total players: ${_audioPlayers.length}');
      
      // 停止并销毁所有播放器实例
      for (final player in _audioPlayers) {
        try {
          await player.stop();
          await player.dispose();
          print('Player stopped and disposed');
        } catch (e) {
          print('Error stopping individual player: $e');
        }
      }
      
      // 清空播放器列表
      _audioPlayers.clear();
      print('All sounds stopped, players list cleared');
    } catch (e) {
      print('Error stopping sound: $e');
      // 即使出错，也要清空播放器列表
      _audioPlayers.clear();
      print('Players list cleared after error');
    }
  }

  /// 暂停所有当前播放的音频
  Future<void> pauseSound() async {
    try {
      print('Attempting to pause all sounds');
      for (final player in _audioPlayers) {
        await player.pause();
      }
      print('All sounds paused successfully');
    } catch (e) {
      print('Error pausing sound: $e');
    }
  }

  /// 恢复所有音频播放
  Future<void> resumeSound() async {
    try {
      print('Attempting to resume all sounds');
      for (final player in _audioPlayers) {
        await player.resume();
      }
      print('All sounds resumed successfully');
    } catch (e) {
      print('Error resuming sound: $e');
    }
  }

  /// 设置所有播放器的音量 (0.0 到 1.0)
  Future<void> setVolume(double volume) async {
    try {
      print('Attempting to set volume to: $volume');
      for (final player in _audioPlayers) {
        await player.setVolume(volume);
      }
      print('Volume set to: $volume for all players');
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// 播放通知声音
  Future<void> playNotificationSound() async {
    print('playNotificationSound called');
    await playSound(AudioType.notification);
  }

  /// 播放闹钟声音
  Future<void> playAlarmSound() async {
    await playSound(AudioType.alarm);
  }

  /// 播放铃声
  Future<void> playBellSound() async {
    await playSound(AudioType.bell);
  }

  /// 播放提示音
  Future<void> playChimeSound() async {
    await playSound(AudioType.chime);
  }

  /// 播放随机音频
  Future<void> playRandomSound() async {
    print('playRandomSound called');
    final audioTypes = AudioType.values;
    final randomIndex = DateTime.now().millisecond % audioTypes.length;
    final randomAudioType = audioTypes[randomIndex];
    print('Playing random sound: $randomAudioType');
    await playSound(randomAudioType);
  }

  /// 根据字符串类型播放指定音频
  Future<void> playSpecificSound(String audioType) async {
    print('playSpecificSound called with: $audioType');
    
    // 音频类型到文件名的映射
    final Map<String, String> audioTypeToFileName = {
      'default': 'notification_sound.mp3',
      'bell': 'bell_sound.mp3',
      'chime': 'chime_sound.mp3',
      'notification': 'notification_sound.mp3',
      'alarm': 'alarm_sound.mp3',
      'BELLLrg_Church bell': 'BELLLrg_Church bell.wav',
      'Ba': 'Ba.mp3',
      'BellNotification': 'BellNotification.mp3',
      'BellRing': 'BellRing.mp3',
      'Deng': 'Deng.wav',
      'Ding': 'Ding.mp3',
      'DingEnd': 'DingEnd.MP3',
      'KeTingEnd': 'KeTingEnd.MP3',
      'Livechat': 'Livechat.mp3',
      'Notification': 'Notification.mp3',
      'Notification2': 'Notification2.mp3',
      'Notification3': 'Notification3.mp3',
      'Piano': 'Piano.mp3',
      'Rock': 'Rock.mp3',
      'cute_notification_sounds': 'cute_notification_sounds.mp3',
      'silence': 'silence.mp3',
    };
    
    // 获取对应的文件名
    final String? fileName = audioTypeToFileName[audioType];
    
    if (fileName != null) {
      try {
        print('Attempting to play sound: $fileName');
        
        // 直接使用文件名，因为音频文件在assets/audio目录中
        final assetSource = AssetSource('audio/$fileName');
        print('AssetSource created: ${assetSource.path}');
        
        // 创建新的音频播放器实例
        final player = AudioPlayer();
        _audioPlayers.add(player);
        print('Created new AudioPlayer instance, total players: ${_audioPlayers.length}');
        
        // 播放音频
        await player.play(assetSource);
        print('Play called successfully');

        print('Sound played successfully: $fileName');
      } catch (e) {
        print('Error playing sound: $e');
        // 如果播放失败，尝试播放默认音频
        await playNotificationSound();
      }
    } else {
      print('Unknown audio type, playing default notification sound');
      await playNotificationSound();
    }
  }

  /// 释放所有资源
  Future<void> dispose() async {
    try {
      print('Attempting to dispose all audio players');
      for (final player in _audioPlayers) {
        await player.dispose();
      }
      _audioPlayers.clear();
      print('All audio players disposed successfully');
    } catch (e) {
      print('Error disposing audio player: $e');
    }
  }
}
