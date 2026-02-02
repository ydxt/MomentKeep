import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/plan.dart';

/// 计划事件
abstract class PlanEvent extends Equatable {
  const PlanEvent();

  @override
  List<Object> get props => [];
}

/// 加载计划事件
class LoadPlans extends PlanEvent {}

/// 添加计划事件
class AddPlan extends PlanEvent {
  final Plan plan;

  const AddPlan(this.plan);

  @override
  List<Object> get props => [plan];
}

/// 更新计划事件
class UpdatePlan extends PlanEvent {
  final Plan plan;

  const UpdatePlan(this.plan);

  @override
  List<Object> get props => [plan];
}

/// 删除计划事件
class DeletePlan extends PlanEvent {
  final String id;

  const DeletePlan(this.id);

  @override
  List<Object> get props => [id];
}

/// 添加习惯到计划事件
class AddHabitToPlan extends PlanEvent {
  final String planId;
  final String habitId;

  const AddHabitToPlan(this.planId, this.habitId);

  @override
  List<Object> get props => [planId, habitId];
}

/// 从计划中移除习惯事件
class RemoveHabitFromPlan extends PlanEvent {
  final String planId;
  final String habitId;

  const RemoveHabitFromPlan(this.planId, this.habitId);

  @override
  List<Object> get props => [planId, habitId];
}

/// 计划状态
abstract class PlanState extends Equatable {
  const PlanState();

  @override
  List<Object> get props => [];
}

/// 计划初始状态
class PlanInitial extends PlanState {}

/// 计划加载状态
class PlanLoading extends PlanState {}

/// 计划加载完成状态
class PlanLoaded extends PlanState {
  final List<Plan> plans;

  const PlanLoaded(this.plans);

  @override
  List<Object> get props => [plans];
}

/// 计划错误状态
class PlanError extends PlanState {
  final String message;

  const PlanError(this.message);

  @override
  List<Object> get props => [message];
}

/// 计划BLoC
class PlanBloc extends Bloc<PlanEvent, PlanState> {
  /// 模拟计划列表
  List<Plan> _plans = [];

  PlanBloc() : super(PlanInitial()) {
    on<LoadPlans>(_onLoadPlans);
    on<AddPlan>(_onAddPlan);
    on<UpdatePlan>(_onUpdatePlan);
    on<DeletePlan>(_onDeletePlan);
    on<AddHabitToPlan>(_onAddHabitToPlan);
    on<RemoveHabitFromPlan>(_onRemoveHabitFromPlan);

    // Initialize plans
    _plans = [
      Plan(
        id: '1',
        name: '学习计划',
        description: '每天学习2小时',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        isCompleted: false,
        habitIds: [],
      ),
      Plan(
        id: '2',
        name: '健身计划',
        description: '每周健身3次',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        isCompleted: false,
        habitIds: [],
      ),
    ];
  }

  /// 处理加载计划事件
  FutureOr<void> _onLoadPlans(LoadPlans event, Emitter<PlanState> emit) {
    emit(PlanLoading());
    emit(PlanLoaded(List.from(_plans)));
  }

  /// 处理添加计划事件
  FutureOr<void> _onAddPlan(AddPlan event, Emitter<PlanState> emit) {
    // 更新原始数据
    _plans.add(event.plan);

    // 直接使用更新后的原始数据创建新状态
    emit(PlanLoaded(List.from(_plans)));
  }

  /// 处理更新计划事件
  FutureOr<void> _onUpdatePlan(UpdatePlan event, Emitter<PlanState> emit) {
    // 更新原始数据
    final index = _plans.indexWhere((plan) => plan.id == event.plan.id);
    if (index != -1) {
      _plans[index] = event.plan;
    }

    // 直接使用更新后的原始数据创建新状态
    emit(PlanLoaded(List.from(_plans)));
  }

  /// 处理删除计划事件
  FutureOr<void> _onDeletePlan(DeletePlan event, Emitter<PlanState> emit) {
    // 更新原始数据
    _plans.removeWhere((plan) => plan.id == event.id);

    // 直接使用更新后的原始数据创建新状态
    emit(PlanLoaded(List.from(_plans)));
  }

  /// 处理添加习惯到计划事件
  FutureOr<void> _onAddHabitToPlan(
      AddHabitToPlan event, Emitter<PlanState> emit) {
    // 更新原始数据
    final planIndex = _plans.indexWhere((plan) => plan.id == event.planId);
    if (planIndex != -1) {
      final plan = _plans[planIndex];
      if (!plan.habitIds.contains(event.habitId)) {
        _plans[planIndex] = plan.copyWith(
          habitIds: [...plan.habitIds, event.habitId],
        );
      }
    }

    // 直接使用更新后的原始数据创建新状态
    emit(PlanLoaded(List.from(_plans)));
  }

  /// 处理从计划中移除习惯事件
  FutureOr<void> _onRemoveHabitFromPlan(
      RemoveHabitFromPlan event, Emitter<PlanState> emit) {
    // 更新原始数据
    final planIndex = _plans.indexWhere((plan) => plan.id == event.planId);
    if (planIndex != -1) {
      final plan = _plans[planIndex];
      _plans[planIndex] = plan.copyWith(
        habitIds: plan.habitIds.where((id) => id != event.habitId).toList(),
      );
    }

    // 直接使用更新后的原始数据创建新状态
    emit(PlanLoaded(List.from(_plans)));
  }
}
