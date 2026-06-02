# 代码重构指南

## 1. 大型文件拆分策略

### 1.1 当前问题文件统计

| 文件路径 | 行数 | 复杂度 | 建议拆分为 |
|---------|------|--------|-----------|
| `pomodoro_page.dart` | 3500+ | 高 | 8-10 个组件 |
| `diary_page.dart` | 3500+ | 高 | 10-12 个组件 |
| `todo_page.dart` | 3300+ | 高 | 8-10 个组件 |
| `habit_page.dart` | 2200+ | 中 | 6-8 个组件 |
| `dashboard_page.dart` | 4900+ | 高 | 12-15 个组件 |
| `star_exchange_page.dart` | 3251 | 高 | 8-10 个组件 |

### 1.2 拆分原则

#### ✅ 好的拆分
```
✅ 单一职责：每个组件只做一件事
✅ 可复用：提取重复的 UI 模式
✅ 可测试：组件易于单独测试
✅ 可读性：文件名清晰表达用途
✅ 独立状态：组件管理自己的状态
```

#### ❌ 避免的拆分
```
❌ 过度拆分：创建过多小组件（<50行）
❌ 循环依赖：组件之间相互依赖
❌ 丢失上下文：拆分后逻辑不连贯
❌ 破坏封装：暴露过多内部实现
```

---

## 2. Pomodoro 页面拆分示例

### 2.1 目标结构

```
lib/presentation/pages/pomodoro/
├── pomodoro_page.dart                    # 主页面 (200行)
├── pomodoro_view.dart                    # 主视图 (150行)
├── pomodoro_controls.dart                # 控制按钮 (100行)
├── pomodoro_statistics.dart              # 统计面板 (150行)
├── pomodoro_settings_dialog.dart         # 设置对话框 (200行)
└── pomodoro_interruption_dialog.dart     # 中断记录对话框 (100行)

lib/presentation/components/pomodoro/
├── pomodoro_timer_display.dart           # 计时器显示 (150行)
├── pomodoro_progress_ring.dart           # 进度环动画 (100行)
├── pomodoro_duration_selector.dart       # 时长选择器 (100行)
└── pomodoro_charts/
    ├── pomodoro_trend_chart.dart         # 趋势图 (150行)
    ├── pomodoro_distribution_chart.dart  # 分布图 (150行)
    └── pomodoro_efficiency_chart.dart    # 效率图 (150行)
```

### 2.2 实施步骤

#### 步骤 1：创建目录结构

```bash
mkdir -p lib/presentation/pages/pomodoro
mkdir -p lib/presentation/components/pomodoro
mkdir -p lib/presentation/components/pomodoro/pomodoro_charts
```

#### 步骤 2：提取计时器显示组件

```dart
// lib/presentation/components/pomodoro/pomodoro_timer_display.dart

import 'package:flutter/material.dart';

class PomodoroTimerDisplay extends StatelessWidget {
  final bool isFocusMode;
  final bool isRunning;
  final int minutes;
  final int seconds;
  final double progress;
  final VoidCallback onTapTime;

  const PomodoroTimerDisplay({
    Key? key,
    required this.isFocusMode,
    required this.isRunning,
    required this.minutes,
    required this.seconds,
    required this.progress,
    required this.onTapTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(theme);
    final statusText = _getStatusText();

    return Column(
      children: [
        // 状态文本
        Text(
          statusText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 20),

        // 时间显示（可点击编辑）
        GestureDetector(
          onTap: onTapTime,
          child: Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 进度环
        SizedBox(
          width: 250,
          height: 250,
          child: PomodoroProgressRing(
            progress: progress,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ThemeData theme) {
    if (!isRunning) return theme.colorScheme.primary;
    return isFocusMode 
        ? const Color(0xFFE76F51)  // 专注色
        : const Color(0xFF2A9D8F); // 休息色
  }

  String _getStatusText() {
    if (!isRunning) return '准备开始';
    if (isFocusMode) return '专注中';
    return '休息中';
  }
}
```

#### 步骤 3：提取统计组件

```dart
// lib/presentation/pages/pomodoro/pomodoro_statistics.dart

import 'package:flutter/material.dart';

class PomodoroStatistics extends StatelessWidget {
  final Map<String, dynamic> todayFocusStats;
  final Map<String, dynamic> todayRestStats;
  final Map<String, dynamic> yesterdayFocusStats;
  final Map<String, dynamic> yesterdayRestStats;

  const PomodoroStatistics({
    Key? key,
    required this.todayFocusStats,
    required this.todayRestStats,
    required this.yesterdayFocusStats,
    required this.yesterdayRestStats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('统计信息'),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTodayStats(),
                const SizedBox(height: 16),
                _buildYesterdayStats(),
                const SizedBox(height: 16),
                _buildTotals(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStats() {
    return _StatsTable(
      title: '今日统计',
      focusStats: todayFocusStats,
      restStats: todayRestStats,
    );
  }

  Widget _buildYesterdayStats {
    return _StatsTable(
      title: '昨日统计',
      focusStats: yesterdayFocusStats,
      restStats: yesterdayRestStats,
    );
  }

  Widget _buildTotals() {
    return _StatsSummary(
      focusStats: {
        'count': (todayFocusStats['count'] as int) + 
                 (yesterdayFocusStats['count'] as int),
        'duration': (todayFocusStats['duration'] as int) + 
                    (yesterdayFocusStats['duration'] as int),
      },
      restStats: {
        'count': (todayRestStats['count'] as int) + 
                 (yesterdayRestStats['count'] as int),
        'duration': (todayRestStats['duration'] as int) + 
                    (yesterdayRestStats['duration'] as int),
      },
    );
  }
}

class _StatsTable extends StatelessWidget {
  final String title;
  final Map<String, dynamic> focusStats;
  final Map<String, dynamic> restStats;

  const _StatsTable({
    required this.title,
    required this.focusStats,
    required this.restStats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade50),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('类型')),
                Padding(padding: EdgeInsets.all(8), child: Text('完成数')),
                Padding(padding: EdgeInsets.all(8), child: Text('总时长')),
                Padding(padding: EdgeInsets.all(8), child: Text('平均时长')),
                Padding(padding: EdgeInsets.all(8), child: Text('中断次数')),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51).withOpacity(0.1),
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('专注时钟'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${focusStats['count']}'),
                ),
                // ... 其他单元格
              ],
            ),
            // 休息行...
          ],
        ),
      ],
    );
  }
}
```

#### 步骤 4：提取图表组件

```dart
// lib/presentation/components/pomodoro/pomodoro_charts/pomodoro_trend_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PomodoroTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final String selectedTimeRange;
  final Function(String) onTimeRangeChanged;

  const PomodoroTrendChart({
    Key? key,
    required this.trendData,
    required this.selectedTimeRange,
    required this.onTimeRangeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  '专注时长趋势',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 时间范围选择器
            _buildTimeRangeSelector(),
            const SizedBox(height: 16),

            // 图表
            if (trendData.isEmpty)
              const Center(child: Text('暂无数据'))
            else
              SizedBox(
                height: 250,
                child: LineChart(_buildLineChartData(theme)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Row(
      children: ['week', 'month', 'year'].map((range) {
        final isSelected = selectedTimeRange == range;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              onPressed: () => onTimeRangeChanged(range),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
              ),
              child: Text(
                range == 'week' ? '周' : range == 'month' ? '月' : '年',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  LineChartData _buildLineChartData(ThemeData theme) {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < trendData.length) {
                final date = DateTime.parse(trendData[index]['date']);
                return Text('${date.month}/${date.day}');
              }
              return const Text('');
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: trendData.asMap().entries.map((e) {
            return FlSpot(
              e.key.toDouble(),
              e.value['focusDuration'].toDouble(),
            );
          }).toList(),
          isCurved: true,
          color: theme.colorScheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }
}
```

#### 步骤 5：重构主页面

```dart
// lib/presentation/pages/pomodoro/pomodoro_page.dart (重构后 < 200行)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/pomodoro_bloc.dart';
import 'pomodoro_view.dart';

class PomodoroPage extends StatelessWidget {
  const PomodoroPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PomodoroBloc(),
      child: const PomodoroView(),
    );
  }
}

// lib/presentation/pages/pomodoro/pomodoro_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/pomodoro_bloc.dart';
import 'pomodoro_controls.dart';
import 'pomodoro_statistics.dart';
import '../../components/pomodoro/pomodoro_timer_display.dart';
import '../../components/pomodoro/pomodoro_charts/pomodoro_trend_chart.dart';

class PomodoroView extends StatefulWidget {
  const PomodoroView({Key? key}) : super(key: key);

  @override
  State<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends State<PomodoroView> {
  // 只保留视图相关的状态
  bool _isFocusMode = true;
  bool _isFullScreen = false;
  int _focusDuration = 25;
  int _restDuration = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('番茄钟')),
      body: BlocBuilder<PomodoroBloc, PomodoroState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 计时器显示
                      PomodoroTimerDisplay(
                        isFocusMode: _isFocusMode,
                        isRunning: state is PomodoroRunning,
                        minutes: _calculateMinutes(state),
                        seconds: _calculateSeconds(state),
                        progress: _calculateProgress(state),
                        onTapTime: () => _showDurationSelector(context),
                      ),
                      const SizedBox(height: 24),

                      // 控制按钮
                      PomodoroControls(
                        isRunning: state is PomodoroRunning,
                        isPaused: state is PomodoroPaused,
                        onStart: () => _startPomodoro(),
                        onPause: () => _pausePomodoro(),
                        onResume: () => _resumePomodoro(),
                        onStop: () => _stopPomodoro(),
                      ),
                    ],
                  ),
                ),
              ),

              // 统计信息
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PomodoroStatistics(
                    todayFocusStats: _todayFocusStats,
                    todayRestStats: _todayRestStats,
                    yesterdayFocusStats: _yesterdayFocusStats,
                    yesterdayRestStats: _yesterdayRestStats,
                  ),
                ),
              ),

              // 图表
              // ...
            ],
          );
        },
      ),
    );
  }

  // 辅助方法...
}
```

---

## 3. Todo 页面拆分示例

### 3.1 目标结构

```
lib/presentation/pages/todo/
├── todo_page.dart                        # 主页面 (150行)
├── todo_view.dart                        # 主视图 (200行)
├── todo_filters.dart                     # 筛选栏 (150行)
├── todo_stats_panel.dart                 # 统计面板 (150行)
├── todo_search_bar.dart                  # 搜索栏 (100行)
└── todo_multi_select_toolbar.dart        # 批量操作栏 (100行)

lib/presentation/components/todo/
├── todo_item.dart                        # 待办项 (150行)
├── todo_item_slidable.dart               # 可滑动待办项 (100行)
├── todo_priority_icon.dart               # 优先级图标 (50行)
├── todo_date_picker.dart                 # 日期选择器 (150行)
├── todo_repeat_selector.dart             # 重复选择器 (150行)
├── todo_subtask_editor.dart              # 子任务编辑器 (150行)
└── todo_location_picker.dart             # 位置选择器 (100行)
```

---

## 4. Diary 页面拆分示例

### 4.1 目标结构

```
lib/presentation/pages/diary/
├── diary_page.dart                       # 主页面 (150行)
├── diary_view.dart                       # 主视图 (200行)
├── diary_filters.dart                    # 筛选栏 (100行)
├── diary_search_bar.dart                 # 搜索栏 (100行)
└── diary_calendar_view.dart              # 日历视图 (200行)

lib/presentation/components/diary/
├── diary_item.dart                       # 日记项 (150行)
├── diary_preview_card.dart               # 预览卡片 (150行)
├── diary_mood_selector.dart              # 心情选择器 (100行)
├── diary_tag_selector.dart               # 标签选择器 (100行)
└── diary_editor/
    ├── block_editor.dart                 # 块编辑器 (200行)
    ├── text_block.dart                   # 文本块 (100行)
    ├── image_block.dart                  # 图片块 (150行)
    ├── video_block.dart                  # 视频块 (150行)
    ├── audio_block.dart                  # 音频块 (150行)
    ├── drawing_block.dart                # 手绘块 (200行)
    ├── insert_menu.dart                  # 插入菜单 (100行)
    └── drawing_canvas.dart               # 画布组件 (200行)
```

---

## 5. 通用组件提取

### 5.1 可复用组件库

```
lib/presentation/components/common/
├── empty_state.dart                      # 空状态
├── loading_skeleton.dart                 # 骨架屏
├── error_view.dart                       # 错误视图
├── search_bar.dart                       # 搜索栏
├── filter_chip_group.dart                # 筛选芯片组
├── date_range_picker.dart                # 日期范围选择
├── tag_chip.dart                         # 标签芯片
├── category_selector.dart                # 分类选择器
├── image_picker_sheet.dart               # 图片选择底部表单
├── confirm_dialog.dart                   # 确认对话框
├── progress_indicators/
│   ├── circular_progress.dart            # 圆形进度
│   ├── linear_progress.dart              # 线性进度
│   └── segmented_progress.dart           # 分段进度
└── animations/
    ├── fade_in.dart                      # 淡入动画
    ├── slide_in.dart                     # 滑入动画
    └── scale_in.dart                     # 缩放动画
```

---

## 6. 重构工具使用

### 6.1 IDE 重构功能

#### VS Code
```
1. 提取方法：选中代码 → Cmd/Ctrl + . → Extract Method
2. 提取组件：选中 Widget → Cmd/Ctrl + . → Extract Widget
3. 重命名：F2 → 输入新名称
4. 移动文件：拖拽到新目录，自动更新导入
```

#### Android Studio
```
1. 提取方法：选中代码 → Cmd/Ctrl + Alt + M
2. 提取组件：选中 Widget → Cmd/Ctrl + Alt + W
3. 重命名：Shift + F6
4. 安全删除：Cmd/Ctrl + Delete
```

### 6.2 自动化脚本

```bash
#!/bin/bash
# 创建组件模板脚本
# usage: create_component.sh ComponentName

COMPONENT_NAME=$1
FILE_NAME=$(echo $COMPONENT_NAME | sed 's/\([A-Z]\)/_\l\1/g' | sed 's/^_//')

cat > "lib/presentation/components/$FILE_NAME.dart" << EOF
import 'package:flutter/material.dart';

class $COMPONENT_NAME extends StatelessWidget {
  const $COMPONENT_NAME({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Text('$COMPONENT_NAME'),
    );
  }
}
EOF

echo "Created $FILE_NAME.dart"
```

---

## 7. 重构检查清单

### 7.1 重构前检查

- [ ] 有完整的测试覆盖（或至少手动测试过）
- [ ] 在 Git 中有干净的提交
- [ ] 明确重构目标（减少行数？提高可读性？）
- [ ] 评估重构风险（是否影响其他模块？）

### 7.2 重构中检查

- [ ] 每次只重构一个组件
- [ ] 重构后立即运行测试
- [ ] 保持功能不变
- [ ] 代码质量提升（不是平移问题）
- [ ] 更新文档和注释

### 7.3 重构后检查

- [ ] 所有测试通过
- [ ] 功能完全正常
- [ ] 代码行数减少
- [ ] 文件数量合理
- [ ] 无循环依赖
- [ ] 导入路径正确
- [ ] 性能没有下降

---

## 8. 代码质量工具

### 8.1 Lint 配置

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # 强制规则
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    prefer_single_quotes: true
    
    # 建议规则
    sort_child_properties_last: true
    use_key_in_widget_constructors: true
    prefer_if_elements_to_conditional_expressions: true
    
    # 关闭规则（过于严格）
    public_member_api_docs: false
```

### 8.2 代码度量

```bash
# 安装代码度量工具
dart pub global activate dart_code_metrics

# 运行分析
metrics lib/

# 输出报告
metrics lib/ --reporter=json > metrics_report.json
```

### 8.3 复杂度监控

```dart
// 目标指标：
// - 文件行数：< 500 行
// - 方法行数：< 50 行
// - 圈复杂度：< 10
// - 嵌套深度：< 4
// - 参数数量：< 5
```

---

## 9. 逐步重构计划

### 第一周：基础设施
- [ ] 创建组件目录结构
- [ ] 提取通用组件（空状态、骨架屏等）
- [ ] 建立代码规范

### 第二周：Pomodoro 重构
- [ ] 拆分 pomodoro_page.dart
- [ ] 提取图表组件
- [ ] 测试验证

### 第三周：Todo 重构
- [ ] 拆分 todo_page.dart
- [ ] 提取待办项组件
- [ ] 实现子任务功能

### 第四周：Diary 重构
- [ ] 拆分 diary_page.dart
- [ ] 提取编辑器组件
- [ ] 实现手绘功能

### 第五周：优化和测试
- [ ] 性能优化
- [ ] 添加单元测试
- [ ] 文档更新

---

**文档版本**: v1.0  
**创建日期**: 2026年4月8日
