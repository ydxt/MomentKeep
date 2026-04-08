# 拾光记 (Moment Keep) - 项目上下文

## 项目概述

**拾光记 (Moment Keep)** 是一款功能丰富的多平台习惯追踪和个人管理应用，基于 Flutter 3.0+ 框架开发。该应用帮助用户养成良好习惯、提高工作效率、记录生活点滴，提供全方位的个人管理解决方案。

### 核心功能模块

| 模块 | 描述 |
|------|------|
| **待办事项管理** | 创建、编辑、删除待办事项，标记完成状态，设置优先级 |
| **习惯打卡与追踪** | 创建习惯，设置提醒，记录打卡历史，查看统计数据 |
| **富文本日记** | 支持图片、音频等附件，Markdown 格式，标签管理 |
| **番茄钟专注计时** | 专注时间管理，记录专注历史，提高工作效率 |
| **数据统计与分析** | 习惯打卡统计，待办事项完成率，专注时间分析 |
| **积分兑换系统** | 通过完成任务获得积分，兑换各种奖励（优惠券、红包、购物卡等） |
| **回收站功能** | 恢复误删除的项目，防止数据丢失 |
| **个人中心** | 用户信息管理，应用设置，主题切换 |

### 高级特性

- **多平台支持**：Android 6.0+, iOS 12.0+, Windows 7+, macOS 10.14+, Linux, Web
- **响应式设计**：适配不同屏幕尺寸
- **主题切换**：支持明暗主题
- **数据备份**：定期自动备份，手动备份选项
- **本地通知**：习惯提醒等功能
- **安全功能**：生物识别、本地认证、数据加密
- **OCR 文字识别**：Google ML Kit 集成
- **地图与定位**：地理围栏和定位功能

---

## 技术栈

### 前端框架
- **Flutter** 3.0+
- **Dart** SDK >=3.0.0 <4.0.0

### 状态管理
- **BLoC** (flutter_bloc) - 主要业务逻辑状态管理
- **Riverpod** (flutter_riverpod) - 依赖注入和部分状态管理
- **Provider** - 辅助状态管理

### 数据持久化
- **SQLite** (sqflite / sqflite_common_ffi) - 移动端/桌面端数据库
- **SharedPreferences** - 轻量配置存储
- **Web 端**：模拟内存数据库

### 主要第三方库
| 库 | 用途 |
|----|------|
| `flutter_quill` | 富文本编辑器（日记功能） |
| `fl_chart` | 数据图表展示 |
| `table_calendar` | 日历组件 |
| `flutter_local_notifications` | 本地通知 |
| `audioplayers` | 音频播放 |
| `video_player` | 视频播放 |
| `file_picker` / `image_picker` | 文件/图片选择 |
| `google_mlkit_text_recognition` | OCR 文字识别 |
| `geolocator` / `geofence_service` | 定位与地理围栏 |
| `local_auth` / `flutter_secure_storage` | 安全认证与存储 |
| `flutter_map` | 地图功能 |
| `window_manager` | 桌面窗口管理 |
| `lottie` / `flutter_animate` | 动画效果 |

---

## 项目结构

```
momentkeep/
├── android/                    # Android 平台代码
├── ios/                        # iOS 平台代码
├── web/                        # Web 平台代码
├── windows/                    # Windows 平台代码
├── macos/                      # macOS 平台代码
├── linux/                      # Linux 平台代码
├── lib/                        # 核心代码
│   ├── core/                   # 核心配置、服务、主题和工具
│   │   ├── config/             # 应用配置（app_config, database_config）
│   │   ├── services/           # 核心服务（音频、备份、通知、存储、自动清理等）
│   │   ├── theme/              # 主题管理（app_theme, theme_provider）
│   │   └── utils/              # 工具类（加密、ID生成、图片处理、响应式工具等）
│   ├── domain/                 # 领域模型和实体
│   │   └── entities/           # 数据实体（achievement, category, diary, habit, todo, pomodoro 等）
│   ├── presentation/           # UI 层（页面、组件、BLoC）
│   │   ├── blocs/              # BLoC 状态管理（todo, habit, diary, pomodoro 等）
│   │   ├── pages/              # 页面组件
│   │   └── components/         # 可复用组件
│   ├── services/               # 数据库服务
│   │   ├── database_service.dart       # 主数据库服务
│   │   ├── user_database_service.dart  # 用户数据库服务
│   │   ├── sync_service.dart           # 数据同步服务
│   │   └── ...
│   └── main.dart               # 应用入口
├── assets/                     # 静态资源
│   ├── audio/                  # 音频文件（通知音、铃声等）
│   └── images/                 # 图片资源
├── docs/                       # 文档
├── pubspec.yaml                # 项目依赖配置
└── analysis_options.yaml       # 代码分析配置
```

---

## 构建和运行

### 环境要求
- Flutter SDK 3.0+
- Dart SDK >=3.0.0 <4.0.0
- Android Studio / VS Code（推荐）
- 对应平台的开发工具链

### 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用（默认设备）
flutter run

# 指定平台运行
flutter run -d chrome      # Web
flutter run -d windows     # Windows
flutter run -d macos       # macOS
flutter run -d linux       # Linux

# 构建应用
flutter build web          # Web
flutter build windows      # Windows
flutter build macos        # macOS
flutter build apk          # Android APK
flutter build ios          # iOS

# 代码质量检查
flutter analyze

# 运行测试
flutter test

# 生成代码（Riverpod/Freezed 等 codegen）
dart run build_runner build
```

---

## 开发约定

### 状态管理
- 使用 **BLoC 模式** 进行主要业务逻辑的状态管理
- 所有 BLoC 文件位于 `lib/presentation/blocs/` 目录
- 使用 **Riverpod** 进行依赖注入和部分状态管理（如主题管理）

### 代码风格
- 遵循 Flutter 官方代码风格指南
- 使用 `flutter_lints` 进行代码规范检查
- 运行 `flutter analyze` 检查代码质量

### 数据持久化
- 使用 `DatabaseService` 进行主数据库操作（SQLite）
- 使用 `UserDatabaseService` 进行用户相关数据库操作
- 使用 `SharedPreferences` 存储轻量配置信息
- Web 端使用模拟数据库实现

### 主题管理
- 应用主题定义在 `lib/core/theme/app_theme.dart`
- 主题状态管理在 `lib/core/theme/theme_provider.dart`
- 支持明暗主题切换，通过 `ThemeManager` 单例管理

### 入口文件说明 (`main.dart`)
- 应用启动时初始化数据库、主题、窗口管理器（桌面端）
- 自动清理服务在启动时调度
- 检查用户会话状态，决定显示登录页还是主页
- 注册了多个 BLoC Provider 供全局使用

---

## 管理员功能

### 管理员注册入口
1. 打开应用，进入"关于"界面
2. 连续点击应用图标 5 次
3. 输入暗号：`admin_reg`
4. 填写管理员注册信息并注册

### 管理员权限
- 用户管理：查看和管理所有用户
- 系统设置：修改系统级设置
- 数据管理：备份和恢复系统数据
- 日志查看：查看系统日志

---

## 注意事项

1. **数据库初始化**：应用启动时会调用 `DatabaseService().initialize()`，确保 `EncryptionHelper` 已正确初始化
2. **窗口管理**：桌面端（Windows/macOS/Linux）使用 `window_manager` 管理窗口，Web 端不启用
3. **无障碍支持**：仅在 Windows 平台上禁用无障碍支持，避免崩溃
4. **本地化**：支持中文（zh_CN）和英文（en_US）
5. **自动清理**：`AutoCleanupService` 负责清理过期商品及其媒体文件
