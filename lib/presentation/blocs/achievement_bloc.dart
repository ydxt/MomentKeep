import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/achievement.dart';

/// 成就事件
abstract class AchievementEvent extends Equatable {
  const AchievementEvent();

  @override
  List<Object> get props => [];
}

/// 加载成就事件
class LoadAchievements extends AchievementEvent {}

/// 更新成就进度事件
class UpdateAchievementProgress extends AchievementEvent {
  final AchievementType type;
  final int progress;

  const UpdateAchievementProgress(this.type, this.progress);

  @override
  List<Object> get props => [type, progress];
}

/// 解锁成就事件
class UnlockAchievement extends AchievementEvent {
  final String id;

  const UnlockAchievement(this.id);

  @override
  List<Object> get props => [id];
}

/// 从真实数据计算成就进度事件
class CalculateAchievementProgress extends AchievementEvent {
  const CalculateAchievementProgress();

  @override
  List<Object> get props => [];
}

/// 成就状态
abstract class AchievementState extends Equatable {
  const AchievementState();

  @override
  List<Object> get props => [];
}

/// 成就初始状态
class AchievementInitial extends AchievementState {}

/// 成就加载状态
class AchievementLoading extends AchievementState {}

/// 成就加载完成状态
class AchievementLoaded extends AchievementState {
  final List<Achievement> achievements;

  const AchievementLoaded(this.achievements);

  @override
  List<Object> get props => [achievements];
}

/// 成就错误状态
class AchievementError extends AchievementState {
  final String message;

  const AchievementError(this.message);

  @override
  List<Object> get props => [message];
}

/// 成就BLoC
class AchievementBloc extends Bloc<AchievementEvent, AchievementState> {
  /// 成就数据
  List<Achievement> _achievements = [];

  /// SharedPreferences 用于持久化保存成就数据
  late SharedPreferences _prefs;

  AchievementBloc() : super(AchievementInitial()) {
    on<LoadAchievements>(_onLoadAchievements);
    on<UpdateAchievementProgress>(_onUpdateAchievementProgress);
    on<UnlockAchievement>(_onUnlockAchievement);
    on<CalculateAchievementProgress>(_onCalculateAchievementProgress);
  }

  /// 保存成就数据到SharedPreferences
  Future<void> _saveAchievements() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final achievementsJson = jsonEncode(
          _achievements.map((achievement) => achievement.toJson()).toList());
      await _prefs.setString('achievements', achievementsJson);
    } catch (e) {
      print('保存成就数据失败: $e');
    }
  }

  /// 从SharedPreferences加载成就数据
  Future<List<Achievement>> _loadAchievementsFromStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final achievementsJson = _prefs.getString('achievements');
      if (achievementsJson != null) {
        final List<dynamic> achievementsList = jsonDecode(achievementsJson);
        return achievementsList
            .map((achievementJson) =>
                Achievement.fromJson(achievementJson as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('加载成就数据失败: $e');
    }

    // 如果没有保存的数据或加载失败，返回默认的成就列表
    return _getDefaultAchievements();
  }

  /// 获取默认成就列表
  List<Achievement> _getDefaultAchievements() {
    return [
      // 习惯相关成就
      Achievement(
        id: 'habit_1',
        name: '习惯养成者',
        description: '连续打卡7天',
        type: AchievementType.habit,
        isUnlocked: false,
        requiredProgress: 7,
        currentProgress: 0,
      ),
      Achievement(
        id: 'habit_2',
        name: '习惯大师',
        description: '连续打卡30天',
        type: AchievementType.habit,
        isUnlocked: false,
        requiredProgress: 30,
        currentProgress: 0,
      ),
      // 计划相关成就
      Achievement(
        id: 'plan_1',
        name: '计划制定者',
        description: '创建第一个计划',
        type: AchievementType.plan,
        isUnlocked: false,
        requiredProgress: 1,
        currentProgress: 0,
      ),
      Achievement(
        id: 'plan_2',
        name: '计划完成者',
        description: '完成第一个计划',
        type: AchievementType.plan,
        isUnlocked: false,
        requiredProgress: 1,
        currentProgress: 0,
      ),
      // 番茄钟相关成就
      Achievement(
        id: 'pomodoro_1',
        name: '专注初学者',
        description: '完成10个番茄钟',
        type: AchievementType.pomodoro,
        isUnlocked: false,
        requiredProgress: 10,
        currentProgress: 0,
      ),
      Achievement(
        id: 'pomodoro_2',
        name: '专注大师',
        description: '完成100个番茄钟',
        type: AchievementType.pomodoro,
        isUnlocked: false,
        requiredProgress: 100,
        currentProgress: 0,
      ),
      // 待办事项相关成就
      Achievement(
        id: 'todo_1',
        name: '任务完成者',
        description: '完成50个待办事项',
        type: AchievementType.todo,
        isUnlocked: false,
        requiredProgress: 50,
        currentProgress: 0,
      ),
      // 日记相关成就
      Achievement(
        id: 'diary_1',
        name: '记录者',
        description: '写10篇日记',
        type: AchievementType.diary,
        isUnlocked: false,
        requiredProgress: 10,
        currentProgress: 0,
      ),
    ];
  }

  /// 处理加载成就事件
  FutureOr<void> _onLoadAchievements(
      LoadAchievements event, Emitter<AchievementState> emit) async {
    emit(AchievementLoading());
    try {
      // 从存储中加载成就数据
      _achievements = await _loadAchievementsFromStorage();
      emit(AchievementLoaded(_achievements));
    } catch (e) {
      emit(AchievementError('加载成就失败'));
    }
  }

  /// 处理更新成就进度事件
  FutureOr<void> _onUpdateAchievementProgress(
      UpdateAchievementProgress event, Emitter<AchievementState> emit) async {
    if (state is AchievementLoaded) {
      final currentState = state as AchievementLoaded;
      final updatedAchievements = currentState.achievements.map((achievement) {
        if (achievement.type == event.type && !achievement.isUnlocked) {
          final newProgress = achievement.currentProgress + event.progress;
          final isUnlocked = newProgress >= achievement.requiredProgress;
          return achievement.copyWith(
            currentProgress: newProgress,
            isUnlocked: isUnlocked,
            unlockedAt: isUnlocked ? DateTime.now() : null,
          );
        }
        return achievement;
      }).toList();

      _achievements = updatedAchievements;
      await _saveAchievements(); // 保存更新后的成就数据
      emit(AchievementLoaded(updatedAchievements));
    }
  }

  /// 处理解锁成就事件
  FutureOr<void> _onUnlockAchievement(
      UnlockAchievement event, Emitter<AchievementState> emit) async {
    if (state is AchievementLoaded) {
      final currentState = state as AchievementLoaded;
      final updatedAchievements = currentState.achievements.map((achievement) {
        if (achievement.id == event.id && !achievement.isUnlocked) {
          return achievement.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
            currentProgress: achievement.requiredProgress,
          );
        }
        return achievement;
      }).toList();

      _achievements = updatedAchievements;
      await _saveAchievements(); // 保存更新后的成就数据
      emit(AchievementLoaded(updatedAchievements));
    }
  }

  /// 从真实数据计算成就进度
  FutureOr<void> _onCalculateAchievementProgress(
      CalculateAchievementProgress event,
      Emitter<AchievementState> emit) async {
    if (state is AchievementLoaded) {
      // 这里将在后续实现中集成真实数据计算逻辑
      // 目前先保留现有逻辑，但确保成就数据持久化
      emit(AchievementLoaded(_achievements));
    }
  }
}
