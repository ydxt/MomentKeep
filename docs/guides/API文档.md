# 拾光记 API 文档

## 概述

本文档描述拾光记应用的内部 API 接口定义，包括数据库服务接口、状态管理接口和核心服务接口。

## 1. 数据库服务接口

### 1.1 DatabaseService

数据库基础服务，提供通用的数据库操作接口。

```dart
class DatabaseService {
  /// 获取数据库实例
  Future<Database> get database;

  /// 初始化数据库
  Future<void> initialize();

  /// 执行原始 SQL 查询
  ///
  /// [sql] - SQL 查询语句
  /// [arguments] - 查询参数
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]);

  /// 插入数据
  ///
  /// [table] - 表名
  /// [values] - 要插入的数据
  /// [conflictAlgorithm] - 冲突处理策略
  Future<int> insert(String table, Map<String, dynamic> values, {ConflictAlgorithm? conflictAlgorithm});

  /// 更新数据
  ///
  /// [table] - 表名
  /// [values] - 要更新的数据
  /// [where] - WHERE 条件
  /// [whereArgs] - WHERE 参数
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs});

  /// 删除数据
  ///
  /// [table] - 表名
  /// [where] - WHERE 条件
  /// [whereArgs] - WHERE 参数
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});

  /// 查询数据
  ///
  /// [table] - 表名
  /// [columns] - 要查询的列
  /// [where] - WHERE 条件
  /// [whereArgs] - WHERE 参数
  /// [groupBy] - GROUP BY 子句
  /// [having] - HAVING 子句
  /// [orderBy] - ORDER BY 子句
  /// [limit] - 限制返回数量
  /// [offset] - 偏移量
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });

  /// 关闭数据库连接
  Future<void> close();
}
```

### 1.2 TodoDatabaseService

待办事项数据库服务，提供待办事项相关的数据操作接口。

```dart
class TodoDatabaseService {
  /// 创建待办事项
  ///
  /// [todo] - 待办事项对象
  /// @returns 创建的待办事项 ID
  Future<int> createTodo(Todo todo);

  /// 更新待办事项
  ///
  /// [todo] - 待办事项对象
  /// @returns 影响的行数
  Future<int> updateTodo(Todo todo);

  /// 删除待办事项
  ///
  /// [id] - 待办事项 ID
  /// @returns 影响的行数
  Future<int> deleteTodo(int id);

  /// 获取待办事项
  ///
  /// [id] - 待办事项 ID
  /// @returns 待办事项对象，不存在返回 null
  Future<Todo?> getTodo(int id);

  /// 获取所有待办事项
  ///
  /// [status] - 状态筛选（可选）
  /// [priority] - 优先级筛选（可选）
  /// [date] - 日期筛选（可选）
  /// @returns 待办事项列表
  Future<List<Todo>> getAllTodos({bool? status, int? priority, DateTime? date});

  /// 切换待办事项完成状态
  ///
  /// [id] - 待办事项 ID
  /// @returns 更新后的待办事项
  Future<Todo?> toggleTodoStatus(int id);
}
```

### 1.3 HabitDatabaseService

习惯数据库服务，提供习惯相关的数据操作接口。

```dart
class HabitDatabaseService {
  /// 创建习惯
  ///
  /// [habit] - 习惯对象
  /// @returns 创建的习惯 ID
  Future<int> createHabit(Habit habit);

  /// 更新习惯
  ///
  /// [habit] - 习惯对象
  /// @returns 影响的行数
  Future<int> updateHabit(Habit habit);

  /// 删除习惯
  ///
  /// [id] - 习惯 ID
  /// @returns 影响的行数
  Future<int> deleteHabit(int id);

  /// 获取习惯
  ///
  /// [id] - 习惯 ID
  /// @returns 习惯对象，不存在返回 null
  Future<Habit?> getHabit(int id);

  /// 获取所有习惯
  ///
  /// @returns 习惯列表
  Future<List<Habit>> getAllHabits();

  /// 创建打卡记录
  ///
  /// [record] - 打卡记录对象
  /// @returns 创建的记录 ID
  Future<int> createCheckInRecord(CheckInRecord record);

  /// 获取习惯打卡记录
  ///
  /// [habitId] - 习惯 ID
  /// [startDate] - 开始日期
  /// [endDate] - 结束日期
  /// @returns 打卡记录列表
  Future<List<CheckInRecord>> getCheckInRecords(int habitId, DateTime startDate, DateTime endDate);

  /// 检查是否已打卡
  ///
  /// [habitId] - 习惯 ID
  /// [date] - 日期
  /// @returns 是否已打卡
  Future<bool> isCheckedIn(int habitId, DateTime date);

  /// 获取打卡统计数据
  ///
  /// [habitId] - 习惯 ID
  /// [days] - 统计天数
  /// @returns 统计数据
  Future<Map<String, int>> getCheckInStats(int habitId, int days);
}
```

### 1.4 DiaryDatabaseService

日记数据库服务，提供日记相关的数据操作接口。

```dart
class DiaryDatabaseService {
  /// 创建日记
  ///
  /// [diary] - 日记对象
  /// @returns 创建的日记 ID
  Future<int> createDiary(Diary diary);

  /// 更新日记
  ///
  /// [diary] - 日记对象
  /// @returns 影响的行数
  Future<int> updateDiary(Diary diary);

  /// 删除日记
  ///
  /// [id] - 日记 ID
  /// @returns 影响的行数
  Future<int> deleteDiary(int id);

  /// 获取日记
  ///
  /// [id] - 日记 ID
  /// @returns 日记对象，不存在返回 null
  Future<Diary?> getDiary(int id);

  /// 获取所有日记
  ///
  /// [startDate] - 开始日期（可选）
  /// [endDate] - 结束日期（可选）
  /// [tag] - 标签筛选（可选）
  /// [categoryId] - 分类 ID 筛选（可选）
  /// @returns 日记列表
  Future<List<Diary>> getAllDiaries({
    DateTime? startDate,
    DateTime? endDate,
    String? tag,
    int? categoryId,
  });

  /// 搜索日记
  ///
  /// [keyword] - 搜索关键词
  /// @returns 日记列表
  Future<List<Diary>> searchDiaries(String keyword);
}
```

### 1.5 PomodoroDatabaseService

番茄钟数据库服务，提供番茄钟相关的数据操作接口。

```dart
class PomodoroDatabaseService {
  /// 创建番茄钟记录
  ///
  /// [pomodoro] - 番茄钟对象
  /// @returns 创建的记录 ID
  Future<int> createPomodoro(Pomodoro pomodoro);

  /// 更新番茄钟记录
  ///
  /// [pomodoro] - 番茄钟对象
  /// @returns 影响的行数
  Future<int> updatePomodoro(Pomodoro pomodoro);

  /// 删除番茄钟记录
  ///
  /// [id] - 番茄钟记录 ID
  /// @returns 影响的行数
  Future<int> deletePomodoro(int id);

  /// 获取番茄钟记录
  ///
  /// [id] - 番茄钟记录 ID
  /// @returns 番茄钟对象，不存在返回 null
  Future<Pomodoro?> getPomodoro(int id);

  /// 获取所有番茄钟记录
  ///
  /// [startDate] - 开始日期（可选）
  /// [endDate] - 结束日期（可选）
  /// @returns 番茄钟记录列表
  Future<List<Pomodoro>> getAllPomodoros({DateTime? startDate, DateTime? endDate});

  /// 获取统计数据
  ///
  /// [startDate] - 开始日期
  /// [endDate] - 结束日期
  /// @returns 统计数据（总时长、次数等）
  Future<Map<String, dynamic>> getStats(DateTime startDate, DateTime endDate);
}
```

## 2. BLoC 状态管理接口

### 2.1 TodoBloc

待办事项状态管理。

```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  /// 状态定义
  /// TodoInitial - 初始状态
  /// TodoLoading - 加载中
  /// TodoLoaded - 加载成功
  /// TodoError - 错误状态

  /// 事件定义
  /// LoadTodos - 加载待办事项列表
  /// AddTodo - 添加待办事项
  /// UpdateTodo - 更新待办事项
  /// DeleteTodo - 删除待办事项
  /// ToggleTodo - 切换完成状态
  /// FilterTodos - 筛选待办事项
}

/// 待办事项状态
abstract class TodoState {}

class TodoInitial extends TodoState {}

class TodoLoading extends TodoState {}

class TodoLoaded extends TodoState {
  final List<Todo> todos;
  TodoLoaded(this.todos);
}

class TodoError extends TodoState {
  final String message;
  TodoError(this.message);
}

/// 待办事项事件
abstract class TodoEvent {}

class LoadTodos extends TodoEvent {
  final bool? status;
  final int? priority;
  final DateTime? date;
  LoadTodos({this.status, this.priority, this.date});
}

class AddTodo extends TodoEvent {
  final Todo todo;
  AddTodo(this.todo);
}

class UpdateTodo extends TodoEvent {
  final Todo todo;
  UpdateTodo(this.todo);
}

class DeleteTodo extends TodoEvent {
  final int id;
  DeleteTodo(this.id);
}

class ToggleTodo extends TodoEvent {
  final int id;
  ToggleTodo(this.id);
}
```

### 2.2 HabitBloc

习惯状态管理。

```dart
class HabitBloc extends Bloc<HabitEvent, HabitState> {
  /// 状态定义
  /// HabitInitial - 初始状态
  /// HabitLoading - 加载中
  /// HabitLoaded - 加载成功
  /// HabitError - 错误状态

  /// 事件定义
  /// LoadHabits - 加载习惯列表
  /// AddHabit - 添加习惯
  /// UpdateHabit - 更新习惯
  /// DeleteHabit - 删除习惯
  /// CheckInHabit - 打卡
  /// LoadCheckInRecords - 加载打卡记录
}

/// 习惯状态
abstract class HabitState {}

class HabitInitial extends HabitState {}

class HabitLoading extends HabitState {}

class HabitLoaded extends HabitState {
  final List<Habit> habits;
  final Map<int, bool> checkInStatus;
  HabitLoaded(this.habits, this.checkInStatus);
}

class HabitError extends HabitState {
  final String message;
  HabitError(this.message);
}

/// 习惯事件
abstract class HabitEvent {}

class LoadHabits extends HabitEvent {}

class AddHabit extends HabitEvent {
  final Habit habit;
  AddHabit(this.habit);
}

class UpdateHabit extends HabitEvent {
  final Habit habit;
  UpdateHabit(this.habit);
}

class DeleteHabit extends HabitEvent {
  final int id;
  DeleteHabit(this.id);
}

class CheckInHabit extends HabitEvent {
  final int habitId;
  final DateTime date;
  CheckInHabit(this.habitId, this.date);
}

class LoadCheckInRecords extends HabitEvent {
  final int habitId;
  final int days;
  LoadCheckInRecords(this.habitId, this.days);
}
```

### 2.3 DiaryBloc

日记状态管理。

```dart
class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  /// 状态定义
  /// DiaryInitial - 初始状态
  /// DiaryLoading - 加载中
  /// DiaryLoaded - 加载成功
  /// DiaryError - 错误状态

  /// 事件定义
  /// LoadDiaries - 加载日记列表
  /// AddDiary - 添加日记
  /// UpdateDiary - 更新日记
  /// DeleteDiary - 删除日记
  /// SearchDiaries - 搜索日记
}
```

### 2.4 PomodoroBloc

番茄钟状态管理。

```dart
class PomodoroBloc extends Bloc<PomodoroEvent, PomodoroState> {
  /// 状态定义
  /// PomodoroInitial - 初始状态
  /// PomodoroRunning - 运行中
  /// PomodoroPaused - 已暂停
  /// PomodoroCompleted - 已完成
  /// PomodoroError - 错误状态

  /// 事件定义
  /// StartTimer - 开始计时
  /// PauseTimer - 暂停计时
  /// ResumeTimer - 恢复计时
  /// StopTimer - 停止计时
  /// SetDuration - 设置时长
  /// LoadRecords - 加载记录
}

/// 番茄钟状态
abstract class PomodoroState {}

class PomodoroInitial extends PomodoroState {}

class PomodoroRunning extends PomodoroState {
  final int remainingSeconds;
  final String note;
  PomodoroRunning(this.remainingSeconds, this.note);
}

class PomodoroPaused extends PomodoroState {
  final int remainingSeconds;
  final String note;
  PomodoroPaused(this.remainingSeconds, this.note);
}

class PomodoroCompleted extends PomodoroState {
  final int duration;
  final String note;
  PomodoroCompleted(this.duration, this.note);
}

/// 番茄钟事件
abstract class PomodoroEvent {}

class StartTimer extends PomodoroEvent {
  final int duration;
  final String note;
  StartTimer(this.duration, this.note);
}

class PauseTimer extends PomodoroEvent {}

class ResumeTimer extends PomodoroEvent {}

class StopTimer extends PomodoroEvent {}

class SetDuration extends PomodoroEvent {
  final int duration;
  SetDuration(this.duration);
}

class LoadRecords extends PomodoroEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  LoadRecords({this.startDate, this.endDate});
}
```

## 3. 核心服务接口

### 3.1 StorageService

存储服务，提供文件存储功能。

```dart
class StorageService {
  /// 保存文件
  ///
  /// [fileName] - 文件名
  /// [data] - 文件数据
  /// @returns 文件保存路径
  Future<String> saveFile(String fileName, Uint8List data);

  /// 读取文件
  ///
  /// [filePath] - 文件路径
  /// @returns 文件数据，不存在返回 null
  Future<Uint8List?> readFile(String filePath);

  /// 删除文件
  ///
  /// [filePath] - 文件路径
  Future<void> deleteFile(String filePath);

  /// 获取文件路径
  ///
  /// [fileName] - 文件名
  /// @returns 文件完整路径
  Future<String> getFilePath(String fileName);

  /// 清空存储
  Future<void> clear();

  /// 获取存储空间信息
  ///
  /// @returns 存储空间信息（已用、可用）
  Future<Map<String, int>> getStorageInfo();
}
```

### 3.2 NotificationService

通知服务，提供本地通知功能。

```dart
class NotificationService {
  /// 初始化通知服务
  Future<void> initialize();

  /// 显示通知
  ///
  /// [id] - 通知 ID
  /// [title] - 通知标题
  /// [body] - 通知内容
  /// [payload] - 自定义数据
  Future<void> showNotification(int id, String title, String body, {String? payload});

  /// 定时通知
  ///
  /// [id] - 通知 ID
  /// [title] - 通知标题
  /// [body] - 通知内容
  /// [scheduledTime] - 定时时间
  /// [payload] - 自定义数据
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime, {
    String? payload,
  });

  /// 重复通知
  ///
  /// [id] - 通知 ID
  /// [title] - 通知标题
  /// [body] - 通知内容
  /// [repeatInterval] - 重复间隔
  /// [payload] - 自定义数据
  Future<void> repeatNotification(
    int id,
    String title,
    String body,
    RepeatInterval repeatInterval, {
    String? payload,
  });

  /// 取消通知
  ///
  /// [id] - 通知 ID
  Future<void> cancelNotification(int id);

  /// 取消所有通知
  Future<void> cancelAllNotifications();

  /// 请求通知权限
  Future<bool> requestPermissions();
}
```

### 3.3 AudioService

音频服务，提供音频播放功能。

```dart
class AudioService {
  /// 播放音频
  ///
  /// [filePath] - 音频文件路径
  /// [volume] - 音量（0.0-1.0）
  Future<void> play(String filePath, {double volume = 1.0});

  /// 暂停播放
  Future<void> pause();

  /// 停止播放
  Future<void> stop();

  /// 恢复播放
  Future<void> resume();

  /// 设置音量
  ///
  /// [volume] - 音量（0.0-1.0）
  Future<void> setVolume(double volume);

  /// 获取播放状态
  ///
  /// @returns 是否正在播放
  bool isPlaying();

  /// 播放系统音效
  ///
  /// [soundName] - 音效名称
  Future<void> playSystemSound(String soundName);
}
```

### 3.4 LocationService

位置服务，提供位置相关功能。

```dart
class LocationService {
  /// 初始化位置服务
  Future<void> initialize();

  /// 获取当前位置
  ///
  /// @returns 位置信息，失败返回 null
  Future<LocationData?> getCurrentLocation();

  /// 开始位置更新
  ///
  /// [callback] - 位置更新回调
  Future<void> startLocationUpdates(Function(LocationData) callback);

  /// 停止位置更新
  Future<void> stopLocationUpdates();

  /// 请求位置权限
  ///
  /// @returns 是否授予权限
  Future<bool> requestPermission();

  /// 检查位置权限
  ///
  /// @returns 是否有权限
  Future<bool> checkPermission();

  /// 计算距离
  ///
  /// [lat1] - 起点纬度
  /// [lon1] - 起点经度
  /// [lat2] - 终点纬度
  /// [lon2] - 终点经度
  /// @returns 距离（米）
  double calculateDistance(double lat1, double lon1, double lat2, double lon2);
}
```

### 3.5 BackupService

备份服务，提供数据备份和恢复功能。

```dart
class BackupService {
  /// 创建备份
  ///
  /// [backupName] - 备份名称
  /// @returns 备份文件路径
  Future<String> createBackup({String? backupName});

  /// 恢复备份
  ///
  /// [backupPath] - 备份文件路径
  Future<void> restoreBackup(String backupPath);

  /// 获取备份列表
  ///
  /// @returns 备份文件列表
  Future<List<BackupInfo>> getBackupList();

  /// 删除备份
  ///
  /// [backupPath] - 备份文件路径
  Future<void> deleteBackup(String backupPath);

  /// 自动备份
  ///
  /// [interval] - 备份间隔（小时）
  Future<void> enableAutoBackup(int interval);

  /// 禁用自动备份
  Future<void> disableAutoBackup();
}
```

## 4. 数据模型定义

### 4.1 Todo（待办事项）

```dart
class Todo {
  final int? id;
  final String title;
  final String? description;
  final int priority; // 0: 低, 1: 中, 2: 高
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;
}
```

### 4.2 Habit（习惯）

```dart
class Habit {
  final int? id;
  final String name;
  final String? description;
  final String icon;
  final int color;
  final int frequency; // 0: 每日, 1: 每周
  final int targetDays;
  final bool hasReminder;
  final List<int> reminderTimes; // 提醒时间（分钟数）
  final DateTime createdAt;
}
```

### 4.3 Diary（日记）

```dart
class Diary {
  final int? id;
  final String title;
  final String content;
  final List<String> tags;
  final int? categoryId;
  final List<String> attachments; // 附件路径列表
  final DateTime createdAt;
  final DateTime? updatedAt;
}
```

### 4.4 Pomodoro（番茄钟）

```dart
class Pomodoro {
  final int? id;
  final int duration; // 专注时长（秒）
  final String note;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isCompleted;
}
```

### 4.5 CheckInRecord（打卡记录）

```dart
class CheckInRecord {
  final int? id;
  final int habitId;
  final DateTime date;
  final String? note;
}
```

## 5. 错误码定义

| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| 1001 | 参数错误 |
| 1002 | 数据库操作失败 |
| 1003 | 文件不存在 |
| 1004 | 权限不足 |
| 1005 | 网络错误 |
| 1006 | 存储空间不足 |
| 2001 | 用户不存在 |
| 2002 | 密码错误 |
| 2003 | 重复注册 |
| 3001 | 待办事项不存在 |
| 3002 | 习惯不存在 |
| 3003 | 日记不存在 |
| 3004 | 番茄钟记录不存在 |

---

**最后更新**：2026-02-02
**文档版本**：1.0.0
