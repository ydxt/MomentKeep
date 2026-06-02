import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/habit_reminder.dart';
import 'dart:async';

/// 习惯提醒事件
abstract class HabitReminderEvent extends Equatable {
  const HabitReminderEvent();

  @override
  List<Object> get props => [];
}

/// 加载习惯提醒事件
class LoadHabitReminders extends HabitReminderEvent {
  final String habitId;

  const LoadHabitReminders(this.habitId);

  @override
  List<Object> get props => [habitId];
}

/// 添加习惯提醒事件
class AddHabitReminder extends HabitReminderEvent {
  final HabitReminder reminder;

  const AddHabitReminder(this.reminder);

  @override
  List<Object> get props => [reminder];
}

/// 更新习惯提醒事件
class UpdateHabitReminder extends HabitReminderEvent {
  final HabitReminder reminder;

  const UpdateHabitReminder(this.reminder);

  @override
  List<Object> get props => [reminder];
}

/// 删除习惯提醒事件
class DeleteHabitReminder extends HabitReminderEvent {
  final String reminderId;

  const DeleteHabitReminder(this.reminderId);

  @override
  List<Object> get props => [reminderId];
}

/// 切换习惯提醒启用状态事件
class ToggleHabitReminderEnabled extends HabitReminderEvent {
  final String reminderId;
  final bool isEnabled;

  const ToggleHabitReminderEnabled(this.reminderId, this.isEnabled);

  @override
  List<Object> get props => [reminderId, isEnabled];
}

/// 切换地理围栏启用状态事件
class ToggleGeofenceEnabled extends HabitReminderEvent {
  final String reminderId;
  final bool isEnabled;

  const ToggleGeofenceEnabled(this.reminderId, this.isEnabled);

  @override
  List<Object> get props => [reminderId, isEnabled];
}

/// 切换智能时段推荐启用状态事件
class ToggleSmartTimeEnabled extends HabitReminderEvent {
  final String reminderId;
  final bool isEnabled;

  const ToggleSmartTimeEnabled(this.reminderId, this.isEnabled);

  @override
  List<Object> get props => [reminderId, isEnabled];
}

/// 习惯提醒状态
abstract class HabitReminderState extends Equatable {
  const HabitReminderState();

  @override
  List<Object> get props => [];
}

/// 习惯提醒初始状态
class HabitReminderInitial extends HabitReminderState {}

/// 习惯提醒加载中状态
class HabitReminderLoading extends HabitReminderState {}

/// 习惯提醒加载完成状态
class HabitReminderLoaded extends HabitReminderState {
  final List<HabitReminder> reminders;

  const HabitReminderLoaded(this.reminders);

  @override
  List<Object> get props => [reminders];
}

/// 习惯提醒操作失败状态
class HabitReminderError extends HabitReminderState {
  final String message;

  const HabitReminderError(this.message);

  @override
  List<Object> get props => [message];
}

/// 习惯提醒BLoC
class HabitReminderBloc extends Bloc<HabitReminderEvent, HabitReminderState> {
  HabitReminderBloc() : super(HabitReminderInitial()) {
    on<LoadHabitReminders>(_onLoadHabitReminders);
    on<AddHabitReminder>(_onAddHabitReminder);
    on<UpdateHabitReminder>(_onUpdateHabitReminder);
    on<DeleteHabitReminder>(_onDeleteHabitReminder);
    on<ToggleHabitReminderEnabled>(_onToggleHabitReminderEnabled);
    on<ToggleGeofenceEnabled>(_onToggleGeofenceEnabled);
    on<ToggleSmartTimeEnabled>(_onToggleSmartTimeEnabled);
  }

  /// 模拟习惯提醒数据
  final List<HabitReminder> _mockReminders = [
    HabitReminder(
      id: '1',
      habitId: '1',
      time: TimeOfDay(hour: 8, minute: 0),
      isEnabled: true,
      isGeofenceEnabled: false,
      isSmartTimeEnabled: true,
      repeatDays: const [true, true, true, true, true, false, false],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    HabitReminder(
      id: '2',
      habitId: '2',
      time: TimeOfDay(hour: 18, minute: 0),
      isEnabled: true,
      isGeofenceEnabled: true,
      latitude: 39.9042,
      longitude: 116.4074,
      radius: 500,
      geofenceName: '家',
      isSmartTimeEnabled: false,
      repeatDays: const [true, true, true, true, true, false, false],
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  /// 处理加载习惯提醒事件
  FutureOr<void> _onLoadHabitReminders(
      LoadHabitReminders event, Emitter<HabitReminderState> emit) {
    emit(HabitReminderLoading());
    try {
      // 模拟异步加载
      Future.delayed(const Duration(milliseconds: 500), () {
        final reminders = _mockReminders
            .where((reminder) => reminder.habitId == event.habitId)
            .toList();
        emit(HabitReminderLoaded(reminders));
      });
    } catch (e) {
      emit(HabitReminderError('加载习惯提醒失败'));
    }
  }

  /// 处理添加习惯提醒事件
  FutureOr<void> _onAddHabitReminder(
      AddHabitReminder event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = [...currentState.reminders, event.reminder];
      emit(HabitReminderLoaded(updatedReminders));
    }
  }

  /// 处理更新习惯提醒事件
  FutureOr<void> _onUpdateHabitReminder(
      UpdateHabitReminder event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = currentState.reminders.map((reminder) {
        return reminder.id == event.reminder.id ? event.reminder : reminder;
      }).toList();
      emit(HabitReminderLoaded(updatedReminders));
    }
  }

  /// 处理删除习惯提醒事件
  FutureOr<void> _onDeleteHabitReminder(
      DeleteHabitReminder event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = currentState.reminders.where((reminder) {
        return reminder.id != event.reminderId;
      }).toList();
      emit(HabitReminderLoaded(updatedReminders));
    }
  }

  /// 处理切换习惯提醒启用状态事件
  FutureOr<void> _onToggleHabitReminderEnabled(
      ToggleHabitReminderEnabled event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = currentState.reminders.map((reminder) {
        if (reminder.id == event.reminderId) {
          return reminder.copyWith(isEnabled: event.isEnabled);
        }
        return reminder;
      }).toList();
      emit(HabitReminderLoaded(updatedReminders));
    }
  }

  /// 处理切换地理围栏启用状态事件
  FutureOr<void> _onToggleGeofenceEnabled(
      ToggleGeofenceEnabled event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = currentState.reminders.map((reminder) {
        if (reminder.id == event.reminderId) {
          return reminder.copyWith(isGeofenceEnabled: event.isEnabled);
        }
        return reminder;
      }).toList();
      emit(HabitReminderLoaded(updatedReminders));
    }
  }

  /// 处理切换智能时段推荐启用状态事件
  FutureOr<void> _onToggleSmartTimeEnabled(
      ToggleSmartTimeEnabled event, Emitter<HabitReminderState> emit) {
    if (state is HabitReminderLoaded) {
      final currentState = state as HabitReminderLoaded;
      final updatedReminders = currentState.reminders.map((reminder) {
        if (reminder.id == event.reminderId) {
          return reminder.copyWith(isSmartTimeEnabled: event.isEnabled);
        }
        return reminder;
      }).toList();
      emit(HabitReminderLoaded(updatedReminders));
    }
  }
}
