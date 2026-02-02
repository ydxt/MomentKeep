import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vibration/vibration.dart';
import 'package:moment_keep/core/services/audio_service.dart';
import 'package:moment_keep/services/database_service.dart';

import 'dart:async';

/// 番茄钟状态枚举
enum PomodoroState {
  focusing,
  resting,
}

/// 番茄钟会话类
class PomodoroSession extends Equatable {
  final String id;
  final String pomodoroId;
  final PomodoroState state;
  final int remainingTime;
  final int totalTime;
  final bool isVibrationEnabled;
  final bool isAudioEnabled;
  final bool isRandomAudioEnabled;
  final bool isAudioSelectionEnabled;
  final String selectedAudio;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PomodoroSession({
    required this.id,
    required this.pomodoroId,
    required this.state,
    required this.remainingTime,
    required this.totalTime,
    required this.isVibrationEnabled,
    required this.isAudioEnabled,
    this.isRandomAudioEnabled = false,
    this.isAudioSelectionEnabled = false,
    this.selectedAudio = 'default',
    required this.createdAt,
    required this.updatedAt,
  });

  PomodoroSession copyWith({
    String? id,
    String? pomodoroId,
    PomodoroState? state,
    int? remainingTime,
    int? totalTime,
    bool? isVibrationEnabled,
    bool? isAudioEnabled,
    bool? isRandomAudioEnabled,
    bool? isAudioSelectionEnabled,
    String? selectedAudio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      pomodoroId: pomodoroId ?? this.pomodoroId,
      state: state ?? this.state,
      remainingTime: remainingTime ?? this.remainingTime,
      totalTime: totalTime ?? this.totalTime,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isRandomAudioEnabled: isRandomAudioEnabled ?? this.isRandomAudioEnabled,
      isAudioSelectionEnabled: isAudioSelectionEnabled ?? this.isAudioSelectionEnabled,
      selectedAudio: selectedAudio ?? this.selectedAudio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object> get props => [
        id,
        pomodoroId,
        state,
        remainingTime,
        totalTime,
        isVibrationEnabled,
        isAudioEnabled,
        isRandomAudioEnabled,
        isAudioSelectionEnabled,
        selectedAudio,
        createdAt,
        updatedAt,
      ];
}

/// 专注成就系统
class FocusAchievements {
  /// 总专注时长（秒）
  static int totalFocusTime = 0;

  /// 已解锁的主题
  static List<String> unlockedThemes = ['default'];

  /// 更新总专注时长
  static void updateTotalFocusTime(int seconds) {
    totalFocusTime += seconds;
    checkAchievements();
  }

  /// 检查并解锁成就
  static void checkAchievements() {
    // 10小时 = 36000秒
    if (totalFocusTime > 36000 && !unlockedThemes.contains('starry_sky')) {
      unlockedThemes.add('starry_sky');
      print('解锁成就：星空主题');
    }

    // 50小时 = 180000秒
    if (totalFocusTime > 180000 && !unlockedThemes.contains('deep_sea')) {
      unlockedThemes.add('deep_sea');
      print('解锁成就：深海主题');
    }
  }

  /// 获取当前主题
  static String getCurrentTheme() {
    if (unlockedThemes.contains('deep_sea')) {
      return 'deep_sea';
    } else if (unlockedThemes.contains('starry_sky')) {
      return 'starry_sky';
    } else {
      return 'default';
    }
  }
}

/// 番茄钟事件
abstract class PomodoroEvent extends Equatable {
  const PomodoroEvent();

  @override
  List<Object> get props => [];
}

/// 开始番茄钟事件
class StartPomodoro extends PomodoroEvent {
  final int duration;
  final int restDuration;
  final PomodoroState initialState;
  final bool isVibrationEnabled;
  final bool isAudioEnabled;
  final bool isRandomAudioEnabled;
  final bool isAudioSelectionEnabled;
  final String selectedAudio;

  const StartPomodoro({
    required this.duration,
    required this.restDuration,
    required this.initialState,
    this.isVibrationEnabled = true,
    this.isAudioEnabled = true,
    this.isRandomAudioEnabled = false,
    this.isAudioSelectionEnabled = false,
    this.selectedAudio = 'default',
  });

  @override
  List<Object> get props => [
        duration,
        restDuration,
        initialState,
        isVibrationEnabled,
        isAudioEnabled,
        isRandomAudioEnabled,
        isAudioSelectionEnabled,
        selectedAudio
      ];
}

/// 暂停番茄钟事件
class PausePomodoro extends PomodoroEvent {}

/// 重置番茄钟事件
class ResetPomodoro extends PomodoroEvent {}

/// 切换震动反馈事件
class ToggleVibration extends PomodoroEvent {}

/// 切换音频反馈事件
class ToggleAudio extends PomodoroEvent {}

/// 更新剩余时间事件
class UpdateRemainingTime extends PomodoroEvent {
  final int remainingTime;

  const UpdateRemainingTime(this.remainingTime);

  @override
  List<Object> get props => [remainingTime];
}

/// 切换到休息状态事件
class SwitchToRest extends PomodoroEvent {}

/// 切换到专注状态事件
class SwitchToFocus extends PomodoroEvent {}

/// 记录中断事件
class RecordInterruption extends PomodoroEvent {
  final String reason;

  const RecordInterruption(this.reason);

  @override
  List<Object> get props => [reason];
}

/// 番茄钟状态
abstract class PomodoroBlocState extends Equatable {
  const PomodoroBlocState();

  @override
  List<Object> get props => [];
}

/// 番茄钟初始状态
class PomodoroInitial extends PomodoroBlocState {}

/// 番茄钟运行状态
class PomodoroRunning extends PomodoroBlocState {
  final PomodoroSession session;

  const PomodoroRunning(this.session);

  @override
  List<Object> get props => [session];
}

/// 番茄钟暂停状态
class PomodoroPaused extends PomodoroBlocState {
  final PomodoroSession session;

  const PomodoroPaused(this.session);

  @override
  List<Object> get props => [session];
}

/// 番茄钟完成状态
class PomodoroCompleted extends PomodoroBlocState {
  final PomodoroSession session;

  const PomodoroCompleted(this.session);

  @override
  List<Object> get props => [session];
}

/// 番茄钟错误状态
class PomodoroError extends PomodoroBlocState {
  final String message;

  const PomodoroError(this.message);

  @override
  List<Object> get props => [message];
}

/// 番茄钟BLoC
class PomodoroBloc extends Bloc<PomodoroEvent, PomodoroBlocState> {
  /// 定时器
  Timer? _timer;

  /// 专注时长（秒）
  static const int _defaultFocusDuration = 25 * 60;

  /// 休息时长（秒）
  static const int _defaultRestDuration = 5 * 60;

  /// 音频服务实例
  final AudioService _audioService = AudioService();

  PomodoroBloc() : super(PomodoroInitial()) {
    on<StartPomodoro>(_onStartPomodoro);
    on<PausePomodoro>(_onPausePomodoro);
    on<ResetPomodoro>(_onResetPomodoro);
    on<ToggleVibration>(_onToggleVibration);
    on<ToggleAudio>(_onToggleAudio);
    on<UpdateRemainingTime>(_onUpdateRemainingTime);
    on<SwitchToRest>(_onSwitchToRest);
    on<SwitchToFocus>(_onSwitchToFocus);
    on<RecordInterruption>(_onRecordInterruption);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  /// 处理开始番茄钟事件
  FutureOr<void> _onStartPomodoro(
      StartPomodoro event, Emitter<PomodoroBlocState> emit) async {
    // 取消现有定时器
    _timer?.cancel();

    // 创建新的番茄钟会话，使用传入的初始状态
    final session = PomodoroSession(
      id: DateTime.now().toString(),
      pomodoroId: DateTime.now().toString(),
      state: event.initialState,
      remainingTime: event.duration,
      totalTime: event.duration,
      isVibrationEnabled: event.isVibrationEnabled,
      isAudioEnabled: event.isAudioEnabled,
      isRandomAudioEnabled: event.isRandomAudioEnabled,
      isAudioSelectionEnabled: event.isAudioSelectionEnabled,
      selectedAudio: event.selectedAudio,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 发射运行状态
    emit(PomodoroRunning(session));

    // 启动定时器
    _startTimer(event.duration);

    // 记录到数据库
    final dbService = DatabaseService();
    try {
      final db = await dbService.database;
      await db.insert('pomodoro_records', {
        'pomodoro_id': session.pomodoroId,
        'todo_id': null,
        'habit_id': null,
        'start_time': DateTime.now().millisecondsSinceEpoch,
        'end_time': null,
        'duration_minutes': event.duration ~/ 60,
        'is_completed': 0,
        'notes': '',
        'state': event.initialState == PomodoroState.focusing
            ? 'focusing'
            : 'resting',
      });
    } catch (e) {
      print('Error recording pomodoro start: $e');
    }
  }

  /// 处理暂停番茄钟事件
  FutureOr<void> _onPausePomodoro(
      PausePomodoro event, Emitter<PomodoroBlocState> emit) async {
    // 取消定时器
    _timer?.cancel();

    // 更新状态为暂停
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;
      emit(PomodoroPaused(currentState.session));

      // 记录暂停到数据库
      final dbService = DatabaseService();
      try {
        final db = await dbService.database;
        await db.update(
            'pomodoro_records',
            {
              'end_time': DateTime.now().millisecondsSinceEpoch,
              'is_completed': 0,
              'notes': '暂停',
            },
            where: 'pomodoro_id = ?',
            whereArgs: [currentState.session.pomodoroId]);
      } catch (e) {
        print('Error recording pomodoro pause: $e');
      }
    }
  }

  /// 处理重置番茄钟事件
  FutureOr<void> _onResetPomodoro(
      ResetPomodoro event, Emitter<PomodoroBlocState> emit) {
    // 取消定时器
    _timer?.cancel();

    // 停止声音
    _audioService.stopSound();

    // 重置状态
    emit(PomodoroInitial());
  }

  /// 处理切换震动反馈事件
  FutureOr<void> _onToggleVibration(
      ToggleVibration event, Emitter<PomodoroBlocState> emit) {
    // 更新震动反馈状态
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;
      final updatedSession = currentState.session.copyWith(
        isVibrationEnabled: !currentState.session.isVibrationEnabled,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroRunning(updatedSession));
    } else if (state is PomodoroPaused) {
      final currentState = state as PomodoroPaused;
      final updatedSession = currentState.session.copyWith(
        isVibrationEnabled: !currentState.session.isVibrationEnabled,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroPaused(updatedSession));
    }
  }

  /// 处理切换音频反馈事件
  FutureOr<void> _onToggleAudio(
      ToggleAudio event, Emitter<PomodoroBlocState> emit) {
    // 更新音频反馈状态
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;
      final updatedSession = currentState.session.copyWith(
        isAudioEnabled: !currentState.session.isAudioEnabled,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroRunning(updatedSession));
    } else if (state is PomodoroPaused) {
      final currentState = state as PomodoroPaused;
      final updatedSession = currentState.session.copyWith(
        isAudioEnabled: !currentState.session.isAudioEnabled,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroPaused(updatedSession));
    }
  }

  /// 处理更新剩余时间事件
  FutureOr<void> _onUpdateRemainingTime(
      UpdateRemainingTime event, Emitter<PomodoroBlocState> emit) async {
    // 更新剩余时间
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;

      // 如果剩余时间为0，停止定时器并发出提示
      if (event.remainingTime <= 0) {
        // 取消定时器
        _timer?.cancel();

        // 结束时播放音频通知
        if (currentState.session.isAudioEnabled) {
          print('Playing notification sound...');
          if (currentState.session.isRandomAudioEnabled) {
            print('Playing random sound...');
            _audioService.playRandomSound();
          } else if (currentState.session.isAudioSelectionEnabled) {
            print('Playing selected sound: ${currentState.session.selectedAudio}');
            _audioService.playSpecificSound(currentState.session.selectedAudio);
          } else {
            print('Playing default notification sound...');
            _audioService.playNotificationSound();
          }
        } else {
          print('Audio is disabled, skipping sound...');
        }

        // 结束时强震动
        if (currentState.session.isVibrationEnabled) {
          Vibration.vibrate(duration: 500, amplitude: 255);
        }

        // 记录完成到数据库
        final dbService = DatabaseService();
        try {
          final db = await dbService.database;
          await db.update(
              'pomodoro_records',
              {
                'end_time': DateTime.now().millisecondsSinceEpoch,
                'is_completed': 1,
              },
              where: 'pomodoro_id = ?',
              whereArgs: [currentState.session.pomodoroId]);
        } catch (e) {
          print('Error recording pomodoro completion: $e');
        }

        // 发射完成状态
        emit(PomodoroCompleted(currentState.session));

        return null;
      }

      // 每5分钟震动一次
      if (event.remainingTime % (5 * 60) == 0 &&
          event.remainingTime != currentState.session.totalTime) {
        if (currentState.session.isVibrationEnabled) {
          Vibration.vibrate(duration: 100, amplitude: 100);
        }
      }

      // 更新会话状态
      final updatedSession = currentState.session.copyWith(
        remainingTime: event.remainingTime,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroRunning(updatedSession));
    }
  }

  /// 处理切换到休息状态事件
  FutureOr<void> _onSwitchToRest(
      SwitchToRest event, Emitter<PomodoroBlocState> emit) {
    // 取消现有定时器
    _timer?.cancel();

    // 切换到休息状态
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;
      // 休息时长应该从当前会话的 restDuration 中获取，但由于我们没有存储这个值，
      // 我们将使用一个合理的默认值。在实际应用中，这个值应该从应用状态或配置中获取。
      final restDuration = _defaultRestDuration;
      final restSession = currentState.session.copyWith(
        state: PomodoroState.resting,
        remainingTime: restDuration,
        totalTime: restDuration,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroRunning(restSession));

      // 启动休息定时器
      _startTimer(restDuration);
    }
  }

  /// 处理切换到专注状态事件
  FutureOr<void> _onSwitchToFocus(
      SwitchToFocus event, Emitter<PomodoroBlocState> emit) {
    // 取消现有定时器
    _timer?.cancel();

    // 切换到专注状态
    if (state is PomodoroRunning) {
      final currentState = state as PomodoroRunning;
      // 专注时长应该从当前会话的 focusDuration 中获取，但由于我们没有存储这个值，
      // 我们将使用一个合理的默认值。在实际应用中，这个值应该从应用状态或配置中获取。
      final focusDuration = _defaultFocusDuration;
      final focusSession = currentState.session.copyWith(
        state: PomodoroState.focusing,
        remainingTime: focusDuration,
        totalTime: focusDuration,
        updatedAt: DateTime.now(),
      );
      emit(PomodoroRunning(focusSession));

      // 启动专注定时器
      _startTimer(focusDuration);
    }
  }

  /// 启动定时器
  void _startTimer(int duration) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state is PomodoroRunning) {
        final currentState = state as PomodoroRunning;
        final remainingTime = currentState.session.remainingTime - 1;
        add(UpdateRemainingTime(remainingTime));
      } else {
        timer.cancel();
      }
    });
  }

  /// 处理记录中断事件
  FutureOr<void> _onRecordInterruption(
      RecordInterruption event, Emitter<PomodoroBlocState> emit) async {
    // 只处理正在运行或暂停的番茄钟会话
    if (state is PomodoroRunning || state is PomodoroPaused) {
      final currentSession = (state as dynamic).session;

      // 记录中断到数据库
      final dbService = DatabaseService();
      try {
        final db = await dbService.database;
        await db.update(
            'pomodoro_records',
            {
              'end_time': DateTime.now().millisecondsSinceEpoch,
              'is_completed': 0,
              'notes': event.reason,
            },
            where: 'pomodoro_id = ?',
            whereArgs: [currentSession.pomodoroId]);

        // 打印日志
        print('已记录中断原因: ${event.reason}');
      } catch (e) {
        print('Error recording interruption: $e');
      }
    }
  }
}
