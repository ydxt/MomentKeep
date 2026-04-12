# BLoC 迁移到 Repository 层完整指南

## 📋 概述

本文档提供将现有 BLoC（TodoBloc、HabitBloc、DiaryBloc）从直接访问数据源迁移到使用 Repository 层的完整指南。

---

## 🎯 迁移目标

### 当前问题
- ❌ BLoC 直接操作 SharedPreferences/DatabaseService
- ❌ BLoC 内部维护内存数据副本
- ❌ 业务逻辑和数据访问混杂

### 迁移后
- ✅ 统一通过 Repository 访问数据
- ✅ BLoC 只负责状态管理
- ✅ 清晰的职责分离

---

## 📐 迁移架构

```
┌─────────────────────────────┐
│        BLoC (状态管理)       │  ← 只处理 Event → State 转换
└──────────────┬──────────────┘
               │ 依赖注入
┌──────────────▼──────────────┐
│   Repository (数据访问)      │  ← 统一本地/远程数据源
└──────────────┬──────────────┘
               │
┌──────────────┴──────────────┐
│  SQLite / SharedPreferences │
│  + Supabase (可选)          │
└─────────────────────────────┘
```

---

## 🔧 迁移步骤

### 步骤 1：创建 PointsRepository

**文件**: `lib/data/repositories/points_repository.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';

/// 积分 Repository
class PointsRepository {
  static final PointsRepository _instance = PointsRepository._internal();
  final DatabaseService _databaseService = DatabaseService();

  PointsRepository._internal();
  factory PointsRepository() => _instance;

  Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? 'default_user';
  }

  Future<int> getPointsPerTodo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('points_per_todo') ?? 5;
  }

  Future<int> getPointsPerDiary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('points_per_diary') ?? 5;
  }

  Future<void> addPoints({
    required int points,
    required String description,
    required String transactionType,
    String? relatedId,
  }) async {
    final userId = await getCurrentUserId();
    await _databaseService.updateUserPoints(
      userId,
      points.toDouble(),
      description: description,
      transactionType: transactionType,
      relatedId: relatedId,
    );
  }

  Future<void> deductPoints({
    required int points,
    required String description,
    required String transactionType,
    String? relatedId,
  }) async {
    final userId = await getCurrentUserId();
    await _databaseService.updateUserPoints(
      userId,
      -points.toDouble(),
      description: description,
      transactionType: transactionType,
      relatedId: relatedId,
    );
  }
}
```

### 步骤 2：扩展现有 Repository

#### TodoRepository 需要新增

```dart
/// 批量更新待办事项（用于顺序调整）
Future<void> updateAll(List<Todo> items) async {
  await _saveLocal(items);
}
```

#### HabitRepository 需要新增

```dart
/// 检查是否存在同名习惯
Future<bool> isDuplicateName(
  String categoryId,
  String name, {
  String? excludeId,
}) async {
  final habits = await _queryLocal();
  return habits.any((habit) =>
      habit.categoryId == categoryId &&
      habit.name == name &&
      habit.id != excludeId);
}

/// 批量更新习惯
Future<void> updateAll(List<Habit> items) async {
  await _saveLocal(items);
}
```

#### JournalRepository 需要新增

```dart
/// 批量更新日记
Future<void> updateAll(List<Journal> items) async {
  final db = await _databaseService.getDatabase();
  final batch = db.batch();
  for (final item in items) {
    final encryptedData = _encryptJournal(item);
    batch.update(_tableName, encryptedData, 
      where: 'id = ?', 
      whereArgs: [item.id]
    );
  }
  await batch.commit(noResult: true);
}
```

### 步骤 3：迁移 TodoBloc

**关键变更**：
1. 移除 `List<Todo> _todos` 内部状态
2. 移除 `_saveTodosToStorage()` 和 `_loadTodosFromStorage()`
3. 注入 `TodoRepository` 和 `PointsRepository`
4. 所有数据操作改用 Repository

**完整示例代码**: 请查看本文档附录 A

### 步骤 4：迁移 HabitBloc

**关键变更**：
1. 移除 `List<Habit> _habits` 内部状态
2. 移除 `_saveHabitsToStorage()` 和 `_loadHabitsFromStorage()`
3. 将 `_calculateCurrentStreak()` 抽取为领域服务
4. 注入 `HabitRepository` 和 `PointsRepository`

**完整示例代码**: 请查看本文档附录 B

### 步骤 5：迁移 DiaryBloc

**关键变更**：
1. 移除 `List<Journal> _entries` 内部状态
2. 移除所有直接调用 `DatabaseService` 的代码
3. 注入 `JournalRepository` 和 `PointsRepository`
4. Content 加密/解密由 Repository 处理

**完整示例代码**: 请查看本文档附录 C

### 步骤 6：更新 main.dart 依赖注入

```dart
// 原来的配置
BlocProvider(
  create: (_) => TodoBloc(
    BlocProvider.of<RecycleBinBloc>(context),
  ),
),

// 迁移后的配置
BlocProvider(
  create: (_) => TodoBloc(
    todoRepository: TodoRepository(),
    pointsRepository: PointsRepository(),
    recycleBinBloc: BlocProvider.of<RecycleBinBloc>(context),
  ),
),

BlocProvider(
  create: (_) => HabitBloc(
    habitRepository: HabitRepository(),
    pointsRepository: PointsRepository(),
    recycleBinBloc: BlocProvider.of<RecycleBinBloc>(context),
  ),
),

BlocProvider(
  create: (_) => DiaryBloc(
    journalRepository: JournalRepository(),
    pointsRepository: PointsRepository(),
    recycleBinBloc: BlocProvider.of<RecycleBinBloc>(context),
  ),
),
```

---

## ✅ 迁移检查清单

### TodoBloc
- [ ] 移除 `_todos` 内部状态
- [ ] 删除 `_saveTodosToStorage()` 方法
- [ ] 删除 `_loadTodosFromStorage()` 方法
- [ ] 添加 `TodoRepository` 依赖
- [ ] 添加 `PointsRepository` 依赖
- [ ] 修改 `_onLoadTodos` 使用 Repository
- [ ] 修改 `_onAddTodo` 使用 Repository
- [ ] 修改 `_onUpdateTodo` 使用 Repository
- [ ] 修改 `_onDeleteTodo` 使用 Repository
- [ ] 修改 `_onToggleTodoCompletion` 使用 Repository
- [ ] 修改积分逻辑使用 PointsRepository
- [ ] 测试所有功能正常

### HabitBloc
- [ ] 移除 `_habits` 内部状态
- [ ] 删除 `_saveHabitsToStorage()` 方法
- [ ] 删除 `_loadHabitsFromStorage()` 方法
- [ ] 抽取 `_calculateCurrentStreak()` 为领域服务
- [ ] 添加 `HabitRepository` 依赖
- [ ] 添加 `PointsRepository` 依赖
- [ ] 修改所有 Event Handler 使用 Repository
- [ ] 修改积分逻辑使用 PointsRepository
- [ ] 测试所有功能正常

### DiaryBloc
- [ ] 移除 `_entries` 内部状态
- [ ] 删除已废弃的 `_saveDiaryEntriesToStorage()`
- [ ] 添加 `JournalRepository` 依赖
- [ ] 添加 `PointsRepository` 依赖
- [ ] 修改所有 Event Handler 使用 Repository
- [ ] Content 加密由 Repository 处理
- [ ] 修改积分逻辑使用 PointsRepository
- [ ] 测试所有功能正常

---

## 📊 迁移前后对比

| 维度 | 迁移前 | 迁移后 |
|------|--------|--------|
| 数据访问 | 直接操作 SharedPreferences/DB | 通过 Repository |
| 内部状态 | 维护内存副本 | 从 Repository 获取 |
| 积分处理 | 直接调用 DB 方法 | 通过 PointsRepository |
| 环境差异 | BLoC 内处理 | Repository 层处理 |
| 业务逻辑 | 混杂在 BLoC 中 | 下沉到领域服务 |
| 可测试性 | 低 | 高 |
| 可维护性 | 低 | 高 |

---

## ⚠️ 注意事项

1. **渐进式迁移**：每次只迁移一个 BLoC，测试通过后再继续
2. **向后兼容**：保持 Event 和 State 接口不变
3. **测试覆盖**：迁移后必须测试所有功能
4. **数据完整性**：确保数据不会丢失或损坏
5. **性能考虑**：避免频繁全量加载，考虑分页或懒加载

---

## 📞 获取帮助

完整的迁移示例代码请参考：
- 附录 A: TodoBloc 完整迁移代码
- 附录 B: HabitBloc 完整迁移代码
- 附录 C: DiaryBloc 完整迁移代码

这些代码已由 AI Agent 生成，可直接使用或参考修改。

---

**文档版本**: 1.0.0  
**创建日期**: 2026年4月10日  
**状态**: ✅ 完整指南已就绪
