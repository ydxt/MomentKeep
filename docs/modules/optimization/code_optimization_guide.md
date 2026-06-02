# MomentKeep 代码优化完整指南

## 📋 优化概览

本文档提供完整的代码优化指南，包括自动化脚本、手动修复步骤和最佳实践。

---

## 🔴 P0 优先级优化（立即执行）

### 1. 批量替换 print 为 debugPrint

#### 问题统计
- **总数**: 约 1200+ 处
- **影响**: 生产环境无法控制日志，性能影响
- **风险**: 低（纯文本替换）

#### 自动化修复脚本

**Windows PowerShell**:
```powershell
# 在项目根目录执行
Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding UTF8
    if ($content -match "print\(") {
        $content = $content -replace 'print\(', 'debugPrint('
        Set-Content $_.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "Fixed: $($_.Name)"
    }
}
```

**Linux/Mac (bash)**:
```bash
find lib -name "*.dart" -type f -exec sed -i 's/\bprint(/debugPrint(/g' {} +
```

#### 手动检查清单

替换后需要手动检查的地方：
- [ ] 确保文件已导入 `package:flutter/foundation.dart`
- [ ] 检查是否有字符串拼接的 print（可能需要格式化）
- [ ] 验证替换后的代码编译通过

#### 批量添加导入

创建脚本 `scripts/add_debug_print_import.dart`:
```dart
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  for (final file in libDir.listSync(recursive: true)) {
    if (file.path.endsWith('.dart')) {
      final content = File(file.path).readAsStringSync();
      if (content.contains('debugPrint(') && 
          !content.contains('package:flutter/foundation.dart')) {
        final newContent = "import 'package:flutter/foundation.dart';\n$content";
        File(file.path).writeAsStringSync(newContent);
        print('Added import: ${file.path}');
      }
    }
  }
}
```

运行:
```bash
dart scripts/add_debug_print_import.dart
```

---

### 2. 修复空 catch 块

#### 问题统计
- **总数**: 7 处
- **影响**: 异常被吞掉，难以调试
- **风险**: 低

#### 需要修复的文件

运行以下命令查找:
```bash
findstr /s /n /c:"catch (_) {}" lib\*.dart
```

#### 修复模板

**修复前**:
```dart
try {
  await someOperation();
} catch (_) {}
```

**修复后**:
```dart
try {
  await someOperation();
} catch (e, stackTrace) {
  debugPrint('Operation failed: $e\n$stackTrace');
}
```

#### 自动化脚本

`scripts/fix_empty_catches.dart`:
```dart
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  int fixed = 0;
  
  for (final file in libDir.listSync(recursive: true)) {
    if (!file.path.endsWith('.dart')) continue;
    
    var content = File(file.path).readAsStringSync();
    
    // 匹配 catch (_) {}
    final pattern = RegExp(r'catch \(_\) \{\s*\}');
    if (pattern.hasMatch(content)) {
      content = content.replaceAllMapped(pattern, (match) {
        fixed++;
        return '''catch (e, stackTrace) {
  debugPrint('Operation failed: \$e\\n\$stackTrace');
}''';
      });
      File(file.path).writeAsStringSync(content);
      print('Fixed empty catches in: ${file.path}');
    }
  }
  
  print('Total fixed: $fixed');
}
```

---

### 3. 检查和修复内存泄漏

#### 常见内存泄漏模式

**1. StreamController 未关闭**

查找未关闭的 StreamController:
```bash
findstr /s /n /c:"StreamController" lib\*.dart
```

**修复模板**:
```dart
// ❌ 错误
class SomeService {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;
}

// ✅ 正确
class SomeService {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;
  
  void dispose() {
    _controller.close();
  }
}
```

**2. Timer 未取消**

```dart
// ❌ 错误
Timer.periodic(Duration(seconds: 1), (timer) {
  doSomething();
});

// ✅ 正确
Timer? _timer;

void startTimer() {
  _timer = Timer.periodic(Duration(seconds: 1), (timer) {
    doSomething();
  });
}

void stopTimer() {
  _timer?.cancel();
  _timer = null;
}
```

**3. AnimationController 未释放**

```dart
@override
void dispose() {
  _animationController.dispose();
  super.dispose();
}
```

#### 自动化检查脚本

`scripts/check_memory_leaks.dart`:
```dart
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final issues = <String>[];
  
  for (final file in libDir.listSync(recursive: true)) {
    if (!file.path.endsWith('.dart')) continue;
    
    final content = File(file.path).readAsStringSync();
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 检查 StreamController 是否有对应的 close
      if (line.contains('StreamController') && 
          !content.contains('.close()')) {
        issues.add('${file.path}:${i+1} - StreamController without close()');
      }
      
      // 检查 StatefulWidget 是否有 dispose
      if (line.contains('State<') && 
          !content.contains('void dispose()')) {
        issues.add('${file.path}:${i+1} - StatefulWidget without dispose()');
      }
    }
  }
  
  if (issues.isNotEmpty) {
    print('Found ${issues.length} potential memory leak(s):');
    for (final issue in issues) {
      print('  $issue');
    }
  } else {
    print('No obvious memory leaks found!');
  }
}
```

---

## 🟡 P1 优先级优化（近期执行）

### 4. 创建常量管理类

#### 问题
魔法字符串和数字散布在代码中：
```dart
prefs.getString('user_id')
prefs.getInt('points_per_todo')
SharedPreferences key: 'todo_entries'
```

#### 解决方案

创建 `lib/core/constants/storage_keys.dart`:
```dart
/// SharedPreferences 存储键名
class StorageKeys {
  // 用户相关
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userUsername = 'user_username';
  
  // 待办事项
  static const String todoEntries = 'todo_entries';
  static const String pointsPerTodo = 'points_per_todo';
  
  // 习惯
  static const String habits = 'habits';
  
  // 分类
  static const String categories = 'categories';
  
  // 日记
  static const String pointsPerDiary = 'points_per_diary';
  
  // 回收站
  static const String recycleBin = 'recycle_bin';
  static const String recycleBinRetentionDays = 'recycle_bin_retention_days';
  
  // 设置
  static const String themeMode = 'theme_mode';
  static const String storagePath = 'storage_path';
  
  // Supabase 同步
  static const String supabaseUrl = 'supabase_url';
  static const String supabaseAnonKey = 'supabase_anon_key';
  static const String syncEnabled = 'sync_enabled';
  static const String realtimeEnabled = 'realtime_enabled';
  static const String lastSyncAt = 'last_sync_at';
  static const String syncStatus = 'sync_status';
  static const String syncConflictStrategy = 'sync_conflict_strategy';
  
  // 离线队列
  static const String syncPendingOperations = 'sync_pending_operations';
}
```

创建 `lib/core/constants/app_constants.dart`:
```dart
/// 应用常量
class AppConstants {
  // 分页
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 超时
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration syncTimeout = Duration(minutes: 5);
  
  // 限制
  static const int maxTitleLength = 100;
  static const int maxContentLength = 10000;
  static const int maxTagsPerItem = 10;
  
  // 默认值
  static const int defaultPointsPerTask = 5;
  static const int defaultRecycleBinRetentionDays = 30;
  
  // 版本
  static const String appVersion = '1.0.0';
  static const int databaseVersion = 17;
  static const String syncProtocolVersion = '1.0.0';
}
```

创建 `lib/core/constants/api_endpoints.dart`:
```dart
/// API 端点常量
class ApiEndpoints {
  // 认证
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
  
  // 待办事项
  static const String todos = '/api/todos';
  static const String todoById = '/api/todos/{id}';
  
  // 习惯
  static const String habits = '/api/habits';
  static const String habitById = '/api/habits/{id}';
  
  // 日记
  static const String journals = '/api/journals';
  static const String journalById = '/api/journals/{id}';
  
  // 分类
  static const String categories = '/api/categories';
  
  // 同步
  static const String sync = '/api/sync';
  static const String syncStatus = '/api/sync/status';
  
  // 文件
  static const String upload = '/api/upload';
  static const String deleteFile = '/api/delete_file';
}
```

#### 批量替换脚本

`scripts/replace_magic_strings.dart`:
```dart
import 'dart:io';

void main() {
  // 示例：替换 user_id
  final replacements = {
    "'user_id'": 'StorageKeys.userId',
    "'todo_entries'": 'StorageKeys.todoEntries',
    "'habits'": 'StorageKeys.habits',
    "'categories'": 'StorageKeys.categories',
  };
  
  final libDir = Directory('lib');
  int fixed = 0;
  
  for (final file in libDir.listSync(recursive: true)) {
    if (!file.path.endsWith('.dart')) continue;
    
    var content = File(file.path).readAsStringSync();
    var original = content;
    
    for (final entry in replacements.entries) {
      content = content.replaceAll(entry.key, entry.value);
    }
    
    if (content != original) {
      // 添加导入
      if (!content.contains('import') || 
          !content.contains('storage_keys.dart')) {
        content = "import 'package:moment_keep/core/constants/storage_keys.dart';\n$content";
      }
      
      File(file.path).writeAsStringSync(content);
      fixed++;
      print('Fixed: ${file.path}');
    }
  }
  
  print('Total files modified: $fixed');
}
```

---

### 5. 后端地址配置化

创建 `lib/core/config/api_config.dart`:
```dart
import 'package:flutter/foundation.dart';

/// API 配置
class ApiConfig {
  /// 基础 URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  
  /// 默认基础 URL（根据环境）
  static String get _defaultBaseUrl {
    if (kDebugMode) {
      return 'http://localhost:6000';
    }
    return 'https://api.example.com'; // 生产环境
  }
  
  /// 超时时间
  static const Duration timeout = Duration(seconds: 30);
  
  /// 重试次数
  static const int maxRetries = 3;
}
```

使用方式:
```bash
# 开发环境
flutter run --dart-define=API_BASE_URL=http://localhost:6000

# 生产环境
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

---

## 🟢 P2 优先级优化（计划中）

### 6. 拆分超大文件

#### 目标文件
- `database_service.dart` (3922 行)
- `product_database_service.dart` (4082 行)

#### 拆分方案

**database_service.dart 拆分**:

```
lib/services/
├── database_service.dart (核心，~500 行)
│   - 单例管理
│   - 初始化
│   - 数据库实例获取
│
├── database_schema.dart (~800 行)
│   - _onCreate()
│   - _onUpgrade()
│   - 表结构定义
│
├── database_migrations.dart (~600 行)
│   - 版本迁移逻辑
│   - 数据迁移脚本
│
├── database_operations/
│   ├── journal_operations.dart (~500 行)
│   ├── user_operations.dart (~400 行)
│   ├── order_operations.dart (~300 行)
│   └── ...其他操作文件
│
└── database_network_service.dart (~300 行)
    - _NetworkService 类
    - Web 平台模拟数据库
```

**拆分步骤**:

1. 创建新文件结构
2. 逐步迁移代码
3. 更新所有引用
4. 测试验证
5. 删除旧文件

---

### 7. 统一状态管理

#### 当前状态
- BLoC: 12 个（主要业务逻辑）
- Riverpod: 主题、导航等
- Provider: 辅助状态

#### 推荐架构

```
 Riverpod (依赖注入 + 轻量状态)
    ↑
 BLoC (复杂业务逻辑状态)
    ↑
 Repository (数据访问层)
```

**统一规则**:
1. **Repository**: 数据访问，单例或 Riverpod Provider
2. **BLoC**: 复杂业务逻辑（待办、习惯、日记等）
3. **Riverpod**: 依赖注入 + 轻量状态（主题、导航、配置）
4. **移除 Provider**: 或用 Riverpod 替代

---

## 📝 自动化优化工具

### 代码格式化
```bash
# 格式化所有 Dart 文件
dart format lib

# 检查代码质量
flutter analyze

# 自动修复部分问题
dart fix --apply
```

### 查找潜在问题
```bash
# 查找所有 print
findstr /s /n "print(" lib\*.dart

# 查找空 catch
findstr /s /n "catch (_) {}" lib\*.dart

# 查找 TODO
findstr /s /n "TODO" lib\*.dart

# 查找未使用的导入
flutter analyze --watch
```

---

## ✅ 优化检查清单

### P0 快速修复
- [ ] 批量替换 print → debugPrint
- [ ] 修复所有空 catch 块
- [ ] 检查 StreamController 关闭
- [ ] 检查 Timer 取消
- [ ] 检查 AnimationController dispose

### P1 代码质量
- [ ] 创建常量管理类
- [ ] 替换魔法字符串/数字
- [ ] 后端地址配置化
- [ ] 添加必要注释

### P2 架构优化
- [ ] 拆分超大文件
- [ ] 统一状态管理
- [ ] 单例改为依赖注入
- [ ] 添加单元测试

---

## 📊 优化收益评估

| 优化项 | 工作量 | 收益 | 优先级 |
|--------|--------|------|--------|
| print → debugPrint | 2天 | ⭐⭐⭐⭐⭐ | P0 |
| 空 catch 修复 | 0.5天 | ⭐⭐⭐⭐⭐ | P0 |
| 内存泄漏检查 | 0.5天 | ⭐⭐⭐⭐⭐ | P0 |
| 常量管理类 | 1天 | ⭐⭐⭐⭐ | P1 |
| 后端地址配置 | 1天 | ⭐⭐⭐ | P1 |
| 拆分超大文件 | 3-5天 | ⭐⭐⭐⭐ | P2 |
| 统一状态管理 | 3天 | ⭐⭐⭐ | P2 |
| 单元测试 | 5天 | ⭐⭐⭐ | P2 |

---

## 🚀 推荐实施顺序

**第 1 周（P0 快速修复）**:
1. Day 1-2: 批量替换 print
2. Day 3: 修复空 catch
3. Day 4-5: 内存泄漏检查

**第 2 周（P1 代码质量）**:
1. Day 1-2: 创建常量类
2. Day 3-4: 替换魔法字符串
3. Day 5: 后端地址配置

**第 3-4 周（P2 架构优化）**:
1. Week 3: 拆分超大文件
2. Week 4: 统一状态管理 + 单元测试

---

**文档版本**: 1.0.0  
**创建日期**: 2026年4月10日  
**状态**: ✅ 完整指南已就绪
