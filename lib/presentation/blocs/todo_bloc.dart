import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/services/location_service.dart';
import 'package:moment_keep/core/services/notification_service.dart';
import 'dart:async';
import 'dart:convert';

/// 待办事项事件
abstract class TodoEvent extends Equatable {
  const TodoEvent();

  @override
  List<Object> get props => [];
}

/// 加载待办事项事件
class LoadTodos extends TodoEvent {}

/// 添加待办事项事件
class AddTodo extends TodoEvent {
  final Todo todo;

  const AddTodo(this.todo);

  @override
  List<Object> get props => [todo];
}

/// 更新待办事项事件
class UpdateTodo extends TodoEvent {
  final Todo todo;

  const UpdateTodo(this.todo);

  @override
  List<Object> get props => [todo];
}

/// 删除待办事项事件
class DeleteTodo extends TodoEvent {
  final String todoId;

  const DeleteTodo(this.todoId);

  @override
  List<Object> get props => [todoId];
}

/// 切换待办事项完成状态事件
class ToggleTodoCompletion extends TodoEvent {
  final String todoId;

  const ToggleTodoCompletion(this.todoId);

  @override
  List<Object> get props => [todoId];
}

/// 更新待办事项顺序事件
class UpdateTodoOrder extends TodoEvent {
  final List<Todo> todos;

  const UpdateTodoOrder(this.todos);

  @override
  List<Object> get props => [todos];
}

/// 待办事项状态
abstract class TodoState extends Equatable {
  const TodoState();

  @override
  List<Object> get props => [];
}

/// 待办事项初始状态
class TodoInitial extends TodoState {}

/// 待办事项加载中状态
class TodoLoading extends TodoState {}

/// 待办事项加载完成状态
class TodoLoaded extends TodoState {
  final List<Todo> todos;

  const TodoLoaded(this.todos);

  @override
  List<Object> get props => [todos];
}

/// 待办事项操作失败状态
class TodoError extends TodoState {
  final String message;

  const TodoError(this.message);

  @override
  List<Object> get props => [message];
}

/// 待办事项BLoC
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  final RecycleBinBloc recycleBinBloc;
  final LocationService _locationService = LocationService();

  final TodoNotificationService _notificationService = TodoNotificationService();

  TodoBloc(this.recycleBinBloc) : 
        super(TodoInitial()) {
    on<LoadTodos>(_onLoadTodos);
    on<AddTodo>(_onAddTodo);
    on<UpdateTodo>(_onUpdateTodo);
    on<DeleteTodo>(_onDeleteTodo);
    on<ToggleTodoCompletion>(_onToggleTodoCompletion);
    on<UpdateTodoOrder>(_onUpdateTodoOrder);

    // 初始化待办事项数据
    _todos = [];
    
    // 初始化通知服务
    _notificationService.initialize();
  }

  List<Todo> _todos = [];
  
  /// 更新位置监控
  Future<void> _updateLocationMonitoring() async {
    // 获取所有带有位置提醒的待办事项
    final todosWithLocationReminders = _todos.where((todo) => 
      todo.isLocationReminderEnabled && 
      !todo.isCompleted &&
      todo.latitude != null &&
      todo.longitude != null &&
      todo.radius != null
    ).toList();
    
    if (todosWithLocationReminders.isNotEmpty) {
      // 启动位置监控
      await _locationService.startLocationMonitoring(todosWithLocationReminders);
    } else {
      // 没有需要位置监控的待办事项，停止监控
      await _locationService.stopLocationMonitoring();
    }
  }

  /// 保存待办事项数据到本地存储
  Future<void> _saveTodosToStorage() async {
    if (kIsWeb) {
      // Web环境下不再使用本地存储，而是在每个操作中直接调用服务器API
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final todosJson = 
          jsonEncode(_todos.map((todo) => todo.toJson()).toList());
      await prefs.setString('todo_entries', todosJson);
    } catch (e) {
      print('保存待办事项数据失败: $e');
    }
  }

  /// 从存储加载待办事项数据
  Future<List<Todo>> _loadTodosFromStorage() async {
    if (kIsWeb) {
      // Web环境下从服务器加载待办事项
      try {
        // 注意：这里应该调用获取待办事项的API，而不是获取日记的API
        // 由于当前DatabaseService没有getTodos方法，暂时返回空列表
        return [];
      } catch (e) {
        print('从服务器加载待办事项失败: $e');
        return [];
      }
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // 使用与_saveTodosToStorage相同的键'todo_entries'
      final todosJson = prefs.getString('todo_entries');
      if (todosJson != null) {
        final List<dynamic> todosList = jsonDecode(todosJson);
        return todosList.map((todoJson) => Todo.fromJson(todoJson)).toList();
      }
    } catch (e) {
      print('加载待办事项数据失败: $e');
    }
    // 如果没有数据或加载失败，返回默认的空列表
    return [];
  }

  /// 处理加载待办事项事件
  FutureOr<void> _onLoadTodos(LoadTodos event, Emitter<TodoState> emit) async {
    emit(TodoLoading());
    try {
      // 从SharedPreferences加载待办事项数据
      _todos = await _loadTodosFromStorage();
      emit(TodoLoaded(List.from(_todos)));
      // 更新位置监控
      await _updateLocationMonitoring();
      // 更新所有待办事项提醒
      await _notificationService.updateAllTodoReminders(_todos);
    } catch (e) {
      emit(TodoError('加载待办事项失败'));
    }
  }

  /// 处理添加待办事项事件
  FutureOr<void> _onAddTodo(AddTodo event, Emitter<TodoState> emit) async {
    // 更新原始数据
    _todos.add(event.todo);

    // 保存到SharedPreferences
    await _saveTodosToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(TodoLoaded(List.from(_todos)));
    // 更新位置监控
    await _updateLocationMonitoring();
    // 设置待办事项提醒
    await _notificationService.scheduleTodoReminder(event.todo);
  }

  /// 处理更新待办事项事件
  FutureOr<void> _onUpdateTodo(
      UpdateTodo event, Emitter<TodoState> emit) async {
    // 更新原始数据
    final index = _todos.indexWhere((todo) => todo.id == event.todo.id);
    if (index != -1) {
      _todos[index] = event.todo;
    }

    // 保存到SharedPreferences
    await _saveTodosToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(TodoLoaded(List.from(_todos)));
    // 更新位置监控
    await _updateLocationMonitoring();
    // 更新待办事项提醒
    await _notificationService.updateTodoReminder(event.todo);
  }

  /// 处理删除待办事项事件
  FutureOr<void> _onDeleteTodo(
      DeleteTodo event, Emitter<TodoState> emit) async {
    // 查找要删除的待办事项
    final todoIndex = _todos.indexWhere((todo) => todo.id == event.todoId);
    if (todoIndex != -1) {
      final deletedTodo = _todos[todoIndex];

      // 将删除的待办事项添加到回收箱
      final recycleBinItem = RecycleBinItem(
        id: deletedTodo.id,
        type: 'todo',
        name: deletedTodo.title,
        data: deletedTodo.toJson(),
        deletedAt: DateTime.now(),
      );
      recycleBinBloc.add(AddToRecycleBin(recycleBinItem));

      // 更新原始数据
      _todos.removeAt(todoIndex);

      // 保存到SharedPreferences
      await _saveTodosToStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(TodoLoaded(List.from(_todos)));
      // 更新位置监控
      await _updateLocationMonitoring();
      // 取消待办事项提醒
      await _notificationService.cancelTodoReminder(event.todoId);
    }
  }

  /// 处理切换待办事项完成状态事件
  FutureOr<void> _onToggleTodoCompletion(
      ToggleTodoCompletion event, Emitter<TodoState> emit) async {
    // 更新原始数据
    final index = _todos.indexWhere((todo) => todo.id == event.todoId);
    if (index != -1) {
      final isCompleted = !_todos[index].isCompleted;
      _todos[index] = _todos[index].copyWith(
        isCompleted: isCompleted,
        updatedAt: DateTime.now(),
        // 当待办事项完成时，记录完成时间
        completedAt: isCompleted ? DateTime.now() : null,
      );

      // 积分相关逻辑
      final DatabaseService databaseService = DatabaseService();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'default_user';
      
      // 获取待办事项完成的积分值和每日上限
      final pointsPerTodo = prefs.getInt('points_per_todo') ?? 5;
      
      if (isCompleted) {
        // 完成待办事项，添加积分
        await databaseService.updateUserPoints(
          userId,
          pointsPerTodo.toDouble(),
          description: '完成待办事项: ${_todos[index].title}',
          transactionType: 'habit_completed',
          relatedId: event.todoId,
        );
        // 取消待办事项提醒
        await _notificationService.cancelTodoReminder(event.todoId);
      } else {
        // 取消完成待办事项，扣除积分
        await databaseService.updateUserPoints(
          userId,
          -pointsPerTodo.toDouble(),
          description: '取消完成待办事项: ${_todos[index].title}',
          transactionType: 'habit_completed',
          relatedId: event.todoId,
        );
        // 重新设置待办事项提醒
        await _notificationService.scheduleTodoReminder(_todos[index]);
      }
    }

    // 保存到SharedPreferences
    await _saveTodosToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(TodoLoaded(List.from(_todos)));
  }

  /// 处理更新待办事项顺序事件
  FutureOr<void> _onUpdateTodoOrder(
      UpdateTodoOrder event, Emitter<TodoState> emit) async {
    // 更新原始数据
    _todos = event.todos;

    // 保存到SharedPreferences
      await _saveTodosToStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(TodoLoaded(List.from(_todos)));
      // 更新位置监控
      await _updateLocationMonitoring();
    }
  }
