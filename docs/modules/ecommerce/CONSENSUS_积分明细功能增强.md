# 积分明细功能增强 - 共识文档

## 1. 明确的需求描述

### 1.1 功能需求
在现有的会员积分页面基础上，增强积分明细功能，包括：

1. **时间筛选功能**
   - 快速筛选：今天、本周、本月、本年
   - 自定义日期范围选择
   - 日期范围验证（开始日期 ≤ 结束日期）

2. **搜索功能**
   - 按积分记录描述/标题进行搜索
   - 支持模糊搜索
   - 实时搜索（输入时自动过滤）

3. **条件筛选功能**
   - 收支类型筛选：全部、收入、支出
   - 交易类型筛选：全部、习惯打卡、待办完成、日记完成、商品兑换、退款
   - 支持组合筛选（时间 + 收支类型 + 交易类型）

4. **收支统计功能**
   - 周账单统计
   - 月账单统计
   - 年账单统计
   - 自定义时间段统计
   - 统计维度：总收入、总支出、净收入、交易次数

5. **图表展示功能**
   - 收支趋势图（折线图）
   - 收支占比图（饼图）
   - 交易类型分布图（柱状图/饼图）
   - 支持切换不同图表类型

### 1.2 界面需求
1. 保持现有会员等级卡片不变
2. 在积分明细列表上方添加筛选栏
3. 筛选栏包含：时间选择按钮、搜索框、统计按钮、收支类型标签
4. 统计功能做成独立页面，通过"统计"按钮导航进入
5. 统计页面包含：概览卡片、图表切换标签、图表展示区域

### 1.3 现有交易类型枚举
基于代码分析，系统中存在以下交易类型：

| transaction_type | 说明 | 收支类型 |
|-----------------|------|---------|
| `habit_completed` | 习惯打卡、待办完成、日记完成 | income/expense |
| `exchange` | 商品兑换（星星商店） | expense |
| `refund` | 退款 | income |
| `reward` | 默认收入类型 | income |
| `expense` | 默认支出类型 | expense |

## 2. 验收标准

### 2.1 功能验收标准

- [ ] 时间筛选：能正确筛选今天、本周、本月、本年的积分记录
- [ ] 自定义时间范围：能选择开始和结束日期，并正确筛选该范围内的记录
- [ ] 搜索功能：输入关键词能正确匹配积分记录的描述
- [ ] 收支类型筛选：能正确筛选全部、收入、支出的记录
- [ ] 交易类型筛选：能正确筛选不同交易类型的记录
- [ ] 组合筛选：时间、收支类型、交易类型能组合使用
- [ ] 周账单统计：能正确统计当前周的收支数据
- [ ] 月账单统计：能正确统计当前月的收支数据
- [ ] 年账单统计：能正确统计当前年的收支数据
- [ ] 自定义时间段统计：能正确统计指定日期范围的收支数据
- [ ] 趋势图：能正确显示所选时间段的收支趋势
- [ ] 占比图：能正确显示所选时间段的收支占比
- [ ] 分布图：能正确显示所选时间段的交易类型分布
- [ ] 数据一致性：所有筛选和统计的数据与积分明细记录一致

### 2.2 用户体验验收标准

- [ ] 筛选操作响应迅速，无明显延迟
- [ ] 筛选状态清晰可见（当前选中的筛选条件）
- [ ] 有清空筛选的快捷方式
- [ ] 图表加载有加载状态提示
- [ ] 空数据状态有友好提示
- [ ] 界面风格与现有应用保持一致

### 2.3 技术验收标准

- [ ] 代码风格与现有代码保持一致
- [ ] 无编译错误和警告
- [ ] 数据库查询使用索引优化性能
- [ ] 错误处理完善，有异常提示
- [ ] 使用 fl_chart 库实现图表功能
- [ ] 遵循项目架构规范

## 3. 技术实现方案

### 3.1 技术栈与依赖

- **UI 框架**：Flutter + Material Design 3
- **状态管理**：StatefulWidget + setState（筛选状态）+ FutureBuilder（统计数据）
- **数据库**：SQLite（sqflite）
- **图表库**：fl_chart ^1.1.1（已在 pubspec.yaml 中）
- **日期处理**：intl ^0.20.2
- **日期选择**：date_field ^6.0.3+1

### 3.2 架构设计

#### 3.2.1 文件结构

```
lib/
├── presentation/
│   ├── pages/
│   │   ├── member_level_page.dart (扩展)
│   │   └── points_statistics_page.dart (新建)
│   └── widgets/
│       └── points/ (新建，可选)
│           ├── points_filter_bar.dart
│           ├── points_chart_trend.dart
│           ├── points_chart_pie.dart
│           └── points_chart_distribution.dart
└── services/
    └── database_service.dart (扩展统计方法)
```

#### 3.2.2 组件设计

**1. member_level_page.dart 扩展**
- 添加筛选状态变量
- 添加筛选栏 UI 组件
- 修改 `_getPointsHistory()` 方法支持筛选参数
- 添加"统计"按钮导航到统计页面

**2. points_statistics_page.dart 新建**
- 独立的统计页面
- 时间范围选择器
- 概览卡片（总收入、总支出、净收入、交易次数）
- 图表切换标签（趋势图、占比图、分布图）
- 图表展示区域

**3. database_service.dart 扩展**
- 添加统计查询方法：
  - `getBillStatistics(userId, startDate, endDate)` - 获取收支统计
  - `getBillTrendData(userId, startDate, endDate)` - 获取趋势图数据
  - `getBillTypeDistribution(userId, startDate, endDate)` - 获取类型分布数据

### 3.3 数据模型

#### 筛选状态模型
```dart
class PointsFilterState {
  DateTime? startDate;
  DateTime? endDate;
  String? searchKeyword;
  String? incomeType; // 'all', 'income', 'expense'
  String? transactionType; // 'all', 'habit_completed', 'exchange', 'refund', etc.
}
```

#### 统计数据模型
```dart
class PointsStatistics {
  final double totalIncome;
  final double totalExpense;
  final double netIncome;
  final int transactionCount;
  final Map<String, double> typeDistribution;
  final List<TrendDataPoint> trendData;
}

class TrendDataPoint {
  final DateTime date;
  final double income;
  final double expense;
}
```

### 3.4 核心功能实现思路

#### 3.4.1 时间筛选
- 快速筛选：预设今天、本周、本月、本年的日期范围
- 自定义筛选：使用日期选择器选择开始和结束日期
- 日期计算：
  - 今天：start = end = DateTime.now()
  - 本周：start = 本周一，end = 本周日
  - 本月：start = 本月1号，end = 本月最后一天
  - 本年：start = 本年1月1号，end = 本年12月31号

#### 3.4.2 搜索功能
- 使用 SQLite 的 LIKE 语句进行模糊搜索
- 搜索字段：`description`
- 实时搜索：debounce 300ms 后执行查询

#### 3.4.3 条件筛选
- 收支类型：WHERE `type` = ?
- 交易类型：WHERE `transaction_type` = ?
- 组合筛选：使用 AND 连接多个条件

#### 3.4.4 统计查询
- 使用 SQL 聚合函数：
  - 总收入：SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END)
  - 总支出：SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END)
  - 交易次数：COUNT(*)
- 趋势数据：按日期分组统计
- 分布数据：按 transaction_type 分组统计

#### 3.4.5 图表实现
- **趋势图**：LineChart，X轴为日期，Y轴为金额，两条线（收入、支出）
- **占比图**：PieChart，两个部分（收入、支出）
- **分布图**：BarChart 或 PieChart，展示各交易类型的占比

## 4. 技术约束与集成方案

### 4.1 技术约束

1. **数据库表结构不变**
   - 继续使用现有的 `bills` 和 `bill_items` 表
   - 不修改表结构

2. **保持现有架构**
   - 数据库操作在 `database_service.dart` 中
   - 页面使用 StatefulWidget + Riverpod（已有）
   - 遵循现有代码风格

3. **性能要求**
   - 积分明细列表：支持大量数据（考虑分页或懒加载）
   - 统计查询：使用数据库聚合，避免全量加载到内存

### 4.2 集成方案

1. **与现有 member_level_page.dart 集成**
   - 在 `_pointsHistory` 上方添加筛选栏
   - 修改 `_loadMemberData()` 方法初始化筛选状态
   - 修改 `_getPointsHistory()` 方法接收筛选参数

2. **与 database_service.dart 集成**
   - 扩展 `getBillItems()` 方法支持可选的筛选参数
   - 添加新的统计查询方法

3. **导航集成**
   - 从 member_level_page 点击"统计"按钮，使用 Navigator.push 导航到 PointsStatisticsPage

## 5. 任务边界限制

### 5.1 包含范围

✅ **必须实现**：
1. 时间筛选（快速筛选 + 自定义范围）
2. 搜索功能（按描述搜索）
3. 收支类型筛选（全部/收入/支出）
4. 交易类型筛选
5. 统计页面（周/月/年/自定义）
6. 三种图表（趋势图、占比图、分布图）
7. 必要的数据库查询方法

### 5.2 排除范围

❌ **不包含**：
1. 修改现有的积分记录逻辑
2. 修改数据库表结构
3. 新增积分获取途径
4. 积分商城相关功能
5. 图表的复杂交互（如点击查看详情）
6. 数据导出功能
7. 多语言支持（使用现有中文即可）

## 6. 风险与应对措施

| 风险 | 影响 | 概率 | 应对措施 |
|-----|------|-----|---------|
| 大量数据导致性能问题 | 高 | 中 | 积分明细考虑分页，统计查询使用数据库聚合 |
| 图表库使用不熟悉 | 中 | 低 | 先做简单实现，参考 fl_chart 官方示例 |
| 日期计算边界情况 | 中 | 低 | 充分测试不同时间范围，包括跨月、跨年 |
| 筛选条件组合复杂 | 中 | 中 | 分步实现，先单条件筛选，再组合筛选 |

---

**共识已达成，可以进入 Architect 阶段**
