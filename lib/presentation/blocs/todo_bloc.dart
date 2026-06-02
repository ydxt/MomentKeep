import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
import 'package:moment_keep/core/services/user_settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/kanban_column.dart';
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

/// 覆盖待办事项事件（原子操作：删除旧记录 + 添加新记录）
class OverwriteTodo extends TodoEvent {
  final List<String> oldTodoIds;
  final Todo newTodo;

  const OverwriteTodo(this.oldTodoIds, this.newTodo);

  @override
  List<Object> get props => [oldTodoIds, newTodo];
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

class LoadKanbanColumns extends TodoEvent {
  const LoadKanbanColumns();
}

class AddKanbanColumn extends TodoEvent {
  final String title;
  final String color;
  const AddKanbanColumn({required this.title, required this.color});

  @override
  List<Object> get props => [title, color];
}

class RenameKanbanColumn extends TodoEvent {
  final String columnId;
  final String newTitle;
  const RenameKanbanColumn({required this.columnId, required this.newTitle});

  @override
  List<Object> get props => [columnId, newTitle];
}

class DeleteKanbanColumn extends TodoEvent {
  final String columnId;
  final bool deleteTodos;
  final String? moveToColumnId;
  const DeleteKanbanColumn({required this.columnId, required this.deleteTodos, this.moveToColumnId});

  @override
  List<Object> get props => [columnId, deleteTodos, moveToColumnId ?? ''];
}

class MoveTodoToColumn extends TodoEvent {
  final String todoId;
  final String targetColumnId;
  const MoveTodoToColumn({required this.todoId, required this.targetColumnId});

  @override
  List<Object> get props => [todoId, targetColumnId];
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
  final List<KanbanColumnEntity> kanbanColumns;

  const TodoLoaded({required this.todos, this.kanbanColumns = const []});

  TodoLoaded copyWith({
    List<Todo>? todos,
    List<KanbanColumnEntity>? kanbanColumns,
  }) {
    return TodoLoaded(
      todos: todos ?? this.todos,
      kanbanColumns: kanbanColumns ?? this.kanbanColumns,
    );
  }

  @override
  List<Object> get props => [todos, kanbanColumns];
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
    on<OverwriteTodo>(_onOverwriteTodo);
    on<LoadKanbanColumns>(_onLoadKanbanColumns);
    on<AddKanbanColumn>(_onAddKanbanColumn);
    on<RenameKanbanColumn>(_onRenameKanbanColumn);
    on<DeleteKanbanColumn>(_onDeleteKanbanColumn);
    on<MoveTodoToColumn>(_onMoveTodoToColumn);

    // 初始化待办事项数据
    _todos = [];
    
    // 初始化通知服务
    _notificationService.initialize();
  }

  List<Todo> _todos = [];
  List<KanbanColumnEntity> _kanbanColumns = [];
  
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
      return;
    }
    
    try {
      final db = DatabaseService();
      final existingTodos = await db.getTodos();
      final existingIds = existingTodos.map((t) => t.id).toSet();
      
      print('[TodoBloc] 保存待办: 内存${_todos.length}条, 数据库${existingTodos.length}条');
      
      for (final todo in _todos) {
        if (existingIds.contains(todo.id)) {
          await db.updateTodo(todo);
        } else {
          await db.insertTodo(todo);
          print('[TodoBloc] 新增待办到数据库: ${todo.id} - ${todo.title} (kanbanColumnId=${todo.kanbanColumnId})');
        }
      }
      
      final currentIds = _todos.map((t) => t.id).toSet();
      for (final existing in existingTodos) {
        if (!currentIds.contains(existing.id)) {
          await db.deleteTodo(existing.id);
          print('[TodoBloc] 从数据库删除待办: ${existing.id} - ${existing.title}');
        }
      }
    } catch (e) {
      print('保存待办事项数据失败: $e');
    }
  }

  /// 从存储加载待办事项数据
  Future<List<Todo>> _loadTodosFromStorage() async {
    if (kIsWeb) {
      return [];
    }
    
    try {
      final db = DatabaseService();
      final dbTodos = await db.getTodos();
      if (dbTodos.isNotEmpty) {
        print('从数据库加载了 ${dbTodos.length} 个待办事项');
        return dbTodos;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final todosJson = prefs.getString('todo_entries');
      if (todosJson != null) {
        print('从 SharedPreferences 迁移待办事项...');
        final List<dynamic> todosList = jsonDecode(todosJson);
        final todos = todosList.map((todoJson) => Todo.fromJson(todoJson)).toList();
        for (final todo in todos) {
          try {
            await db.insertTodo(todo);
          } catch (e) {
            print('迁移待办事项失败: $e, todo: ${todo.title}');
          }
        }
        await prefs.remove('todo_entries');
        print('成功迁移 ${todos.length} 个待办事项到数据库');
        return todos;
      }
      
      print('没有找到待办事项数据');
    } catch (e) {
      print('加载待办事项数据失败: $e');
    }
    return [];
  }

  /// 处理加载待办事项事件
  FutureOr<void> _onLoadTodos(LoadTodos event, Emitter<TodoState> emit) async {
    emit(TodoLoading());
    try {
      _todos = await _loadTodosFromStorage();
      try {
        final db = DatabaseService();
        _kanbanColumns = await db.getKanbanColumns();
        print('[TodoBloc] 加载看板列: ${_kanbanColumns.length}个');
      } catch (e) {
        print('[TodoBloc] 加载看板列失败: $e');
      }
      emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
      await _updateLocationMonitoring();
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
    emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
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
    emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
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
      emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
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
      final userId = prefs.getString(StorageKeys.userId) ?? 'default_user';
      
      final pointsPerTodo = await UserSettingsService().getSettingInt(StorageKeys.pointsPerTodo, defaultValue: 5);
      
      if (isCompleted) {
        final ruleSnapshot = jsonEncode({'points_per_todo': pointsPerTodo});
        await databaseService.updateUserPoints(
          userId,
          pointsPerTodo.toDouble(),
          description: '完成待办事项: ${_todos[index].title}',
          transactionType: 'todo_completed',
          relatedId: event.todoId,
          ruleSnapshot: ruleSnapshot,
        );
        await _notificationService.cancelTodoReminder(event.todoId);
      } else {
        final originalBillItem = await databaseService.getBillItemByRelatedId(userId, event.todoId, 'todo_completed');
        int undoPointsPerTodo = pointsPerTodo;
        if (originalBillItem?.ruleSnapshot != null) {
          try {
            final snapshot = jsonDecode(originalBillItem!.ruleSnapshot!);
            undoPointsPerTodo = snapshot['points_per_todo'] ?? pointsPerTodo;
          } catch (_) {}
        }
        await databaseService.updateUserPoints(
          userId,
          -undoPointsPerTodo.toDouble(),
          description: '取消完成待办事项: ${_todos[index].title}',
          transactionType: 'todo_completed',
          relatedId: event.todoId,
        );
        await _notificationService.scheduleTodoReminder(_todos[index]);
      }
    }

    // 保存到SharedPreferences
    await _saveTodosToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
  }

  /// 处理覆盖待办事项事件（原子操作）
  FutureOr<void> _onOverwriteTodo(OverwriteTodo event, Emitter<TodoState> emit) async {
    // 1. 取消旧待办的通知
    for (final oldId in event.oldTodoIds) {
      await _notificationService.cancelTodoReminder(oldId);
    }

    // 2. 从内存中删除旧记录
    _todos.removeWhere((todo) => event.oldTodoIds.contains(todo.id));

    // 3. 添加新记录
    _todos.add(event.newTodo);

    // 4. 一次性保存到 SharedPreferences
    await _saveTodosToStorage();

    // 5. 发出更新状态
    emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));

    // 6. 更新位置监控
    await _updateLocationMonitoring();

    // 7. 设置新待办的通知
    await _notificationService.scheduleTodoReminder(event.newTodo);
  }

  /// 处理更新待办事项顺序事件
  FutureOr<void> _onUpdateTodoOrder(
      UpdateTodoOrder event, Emitter<TodoState> emit) async {
    _todos = event.todos;
    await _saveTodosToStorage();
    emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
    await _updateLocationMonitoring();
  }

  Future<void> _onLoadKanbanColumns(LoadKanbanColumns event, Emitter<TodoState> emit) async {
    try {
      final db = DatabaseService();
      _kanbanColumns = await db.getKanbanColumns();
      final currentState = state;
      if (currentState is TodoLoaded) {
        emit(currentState.copyWith(kanbanColumns: List.from(_kanbanColumns)));
      } else {
        emit(TodoLoaded(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
      }
    } catch (_) {}
  }

  Future<void> _onAddKanbanColumn(AddKanbanColumn event, Emitter<TodoState> emit) async {
    try {
      final currentState = state;
      if (currentState is TodoLoaded) {
        final maxPosition = _kanbanColumns.isEmpty
            ? 0
            : _kanbanColumns.map((c) => c.position).reduce((a, b) => a > b ? a : b) + 1;
        final db = DatabaseService();
        final userId = await db.getCurrentUserId() ?? 'default_user';
        final column = KanbanColumnEntity(
          id: 'col_${DateTime.now().millisecondsSinceEpoch}',
          title: event.title,
          color: event.color,
          position: maxPosition,
          userId: userId,
        );
        await db.insertKanbanColumn(column);
        _kanbanColumns = [..._kanbanColumns, column];
        emit(currentState.copyWith(kanbanColumns: List.from(_kanbanColumns)));
      }
    } catch (_) {}
  }

  Future<void> _onRenameKanbanColumn(RenameKanbanColumn event, Emitter<TodoState> emit) async {
    try {
      final currentState = state;
      if (currentState is TodoLoaded) {
        final column = _kanbanColumns.firstWhere((c) => c.id == event.columnId);
        final updated = column.copyWith(title: event.newTitle);
        final db = DatabaseService();
        await db.updateKanbanColumn(updated);
        _kanbanColumns = _kanbanColumns.map((c) => c.id == event.columnId ? updated : c).toList();
        emit(currentState.copyWith(kanbanColumns: List.from(_kanbanColumns)));
      }
    } catch (_) {}
  }

  Future<void> _onDeleteKanbanColumn(DeleteKanbanColumn event, Emitter<TodoState> emit) async {
    try {
      final currentState = state;
      if (currentState is TodoLoaded) {
        final db = DatabaseService();
        if (event.deleteTodos) {
          final todosInColumn = _todos.where((t) => t.kanbanColumnId == event.columnId).toList();
          for (final todo in todosInColumn) {
            await _notificationService.cancelTodoReminder(todo.id);
          }
          _todos.removeWhere((t) => t.kanbanColumnId == event.columnId);
          await _saveTodosToStorage();
          await db.deleteKanbanColumn(event.columnId);
          _kanbanColumns = _kanbanColumns.where((c) => c.id != event.columnId).toList();
          emit(currentState.copyWith(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
        } else {
          final todosInColumn = _todos.where((t) => t.kanbanColumnId == event.columnId).toList();
          for (final todo in todosInColumn) {
            final updated = todo.copyWith(kanbanColumnId: event.moveToColumnId);
            final index = _todos.indexWhere((t) => t.id == todo.id);
            if (index != -1) {
              _todos[index] = updated;
            }
          }
          await _saveTodosToStorage();
          await db.deleteKanbanColumn(event.columnId);
          _kanbanColumns = _kanbanColumns.where((c) => c.id != event.columnId).toList();
          emit(currentState.copyWith(todos: List.from(_todos), kanbanColumns: List.from(_kanbanColumns)));
        }
      }
    } catch (_) {}
  }

  Future<void> _onMoveTodoToColumn(MoveTodoToColumn event, Emitter<TodoState> emit) async {
    try {
      final currentState = state;
      if (currentState is TodoLoaded) {
        final index = _todos.indexWhere((t) => t.id == event.todoId);
        if (index != -1) {
          _todos[index] = _todos[index].copyWith(kanbanColumnId: event.targetColumnId);
          await _saveTodosToStorage();
          emit(currentState.copyWith(todos: List.from(_todos)));
        }
      }
    } catch (_) {}
  }
}
