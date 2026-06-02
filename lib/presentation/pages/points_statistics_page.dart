import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 时间范围枚举
enum TimeRange {
  day,
  week,
  month,
  year,
  custom,
}

/// 收支统计页面 - 微信账单风格
class PointsStatisticsPage extends ConsumerStatefulWidget {
  final String? userId;
  
  const PointsStatisticsPage({super.key, this.userId});

  @override
  ConsumerState<PointsStatisticsPage> createState() => _PointsStatisticsPageState();
}

class _PointsStatisticsPageState extends ConsumerState<PointsStatisticsPage> {
  final DatabaseService _databaseService = DatabaseService();
  
  String _userId = 'default_user';
  TimeRange _timeRange = TimeRange.month;
  PointsStatistics? _statistics;
  List<BillItem> _topIncomeItems = [];
  List<BillItem> _topExpenseItems = [];
  bool _isLoading = true;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  final Map<String, String> _transactionTypeMap = {
    'reward': '获得奖励',
    'exchange': '兑换商品',
    'refund': '积分退款',
    'daily_checkin': '每日打卡',
    'habit_completed': '习惯完成',
    'pomodoro_completed': '番茄钟完成',
    'diary_completed': '日记完成',
    'todo_completed': '待办完成',
    'purchase': '购物消费',
  };

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _loadData();
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    switch (_timeRange) {
      case TimeRange.day:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeRange.week:
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        _endDate = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
        _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
        break;
      case TimeRange.month:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case TimeRange.year:
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case TimeRange.custom:
        break;
    }
  }

  String _getTimeRangeLabel() {
    switch (_timeRange) {
      case TimeRange.day:
        return '今日';
      case TimeRange.week:
        return '本周';
      case TimeRange.month:
        return '本月';
      case TimeRange.year:
        return '本年';
      case TimeRange.custom:
        return '自定义';
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _userId = widget.userId ?? await _databaseService.getCurrentUserId() ?? 'default_user';

      _statistics = await _databaseService.getPointsStatistics(
        _userId,
        startDate: _startDate,
        endDate: _endDate,
      );

      _topIncomeItems = await _databaseService.getTopIncomeBillItems(
        _userId,
        startDate: _startDate,
        endDate: _endDate,
        limit: 10,
      );

      _topExpenseItems = await _databaseService.getTopExpenseBillItems(
        _userId,
        startDate: _startDate,
        endDate: _endDate,
        limit: 10,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载统计数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeTimeRange(TimeRange range) {
    setState(() {
      _timeRange = range;
    });
    if (range != TimeRange.custom) {
      _setDefaultDateRange();
      _loadData();
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _timeRange = TimeRange.custom;
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeChatStyleStatCard(theme),
                  const SizedBox(height: 20),
                  _buildTimeRangeTabs(theme),
                  const SizedBox(height: 20),
                  _buildTrendChart(theme),
                  const SizedBox(height: 20),
                  _buildTypeDistributionChart(theme),
                  const SizedBox(height: 20),
                  _buildTopLists(theme),
                ],
              ),
            ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.background,
      elevation: 0,
      title: Text(
        '收支统计',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
      ),
    );
  }

  Widget _buildWeChatStyleStatCard(ThemeData theme) {
    final stats = _statistics;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getTimeRangeLabel()}收支',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeChatStatItem(
                '收入',
                stats.totalIncome,
                Colors.greenAccent,
                theme,
              ),
              _buildWeChatStatItem(
                '支出',
                stats.totalExpense,
                Colors.redAccent,
                theme,
              ),
              _buildWeChatStatItem(
                '结余',
                stats.netIncome,
                stats.netIncome >= 0 ? Colors.greenAccent : Colors.redAccent,
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeChatStatItem(String title, double value, Color color, ThemeData theme, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: isLarge ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                blurRadius: 2,
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value >= 0 ? '+' : ''}${NumberFormat('#,###').format(value.toInt())}',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge ? 32 : 24,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 3,
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeTabs(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTimeRangeTab(theme, TimeRange.day, '日'),
          _buildTimeRangeTab(theme, TimeRange.week, '周'),
          _buildTimeRangeTab(theme, TimeRange.month, '月'),
          _buildTimeRangeTab(theme, TimeRange.year, '年'),
          _buildCustomTimeRangeTab(theme),
        ],
      ),
    );
  }

  Widget _buildTimeRangeTab(ThemeData theme, TimeRange range, String label) {
    final isSelected = _timeRange == range;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeTimeRange(range),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected 
                ? theme.colorScheme.primary 
                : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected 
                  ? theme.colorScheme.onPrimary 
                  : theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTimeRangeTab(ThemeData theme) {
    final isSelected = _timeRange == TimeRange.custom;
    return Expanded(
      child: GestureDetector(
        onTap: _selectCustomDateRange,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected 
                ? theme.colorScheme.primary 
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.date_range,
                size: 16,
                color: isSelected 
                    ? theme.colorScheme.onPrimary 
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 4),
              Text(
                '自定义',
                style: TextStyle(
                  color: isSelected 
                      ? theme.colorScheme.onPrimary 
                      : theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(ThemeData theme) {
    final stats = _statistics;
    if (stats == null || stats.trendData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '收支趋势',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 100,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < stats.trendData.length) {
                          final date = stats.trendData[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      interval: stats.trendData.length > 7 
                          ? (stats.trendData.length / 7).ceilToDouble() 
                          : 1,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value.toInt()),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: stats.trendData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.income);
                    }).toList(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: stats.trendData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), -entry.value.expense);
                    }).toList(),
                    isCurved: true,
                    color: theme.colorScheme.error,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.error.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDistributionChart(ThemeData theme) {
    final stats = _statistics;
    if (stats == null) return const SizedBox.shrink();

    final distribution = stats.typeDistribution;
    if (distribution.isEmpty) return const SizedBox.shrink();

    final total = distribution.values.reduce((a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '收支构成',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sections: distribution.entries.map((entry) {
                        final percentage = entry.value / total;
                        final isIncome = stats.incomeTypeDistribution.containsKey(entry.key);
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${(percentage * 100).toStringAsFixed(0)}%',
                          color: isIncome 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.error,
                          radius: 50,
                          titleStyle: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: distribution.entries.map((entry) {
                    final isIncome = stats.incomeTypeDistribution.containsKey(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isIncome 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _transactionTypeMap[entry.key] ?? entry.key,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopLists(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTopList(
            theme,
            title: '收入排行榜',
            items: _topIncomeItems,
            isIncome: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTopList(
            theme,
            title: '支出排行榜',
            items: _topExpenseItems,
            isIncome: false,
          ),
        ),
      ],
    );
  }

  Widget _buildTopList(
    ThemeData theme, {
    required String title,
    required List<BillItem> items,
    required bool isIncome,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无数据',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildTopListItem(theme, index + 1, item, isIncome);
          }),
        ],
      ),
    );
  }

  Widget _buildTopListItem(
    ThemeData theme,
    int rank,
    BillItem item,
    bool isIncome,
  ) {
    final color = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    final transactionTypeName = _transactionTypeMap[item.transactionType] ?? item.transactionType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: rank <= 3 
                  ? (rank == 1 
                      ? Colors.amber 
                      : rank == 2 
                          ? Colors.grey[400] 
                          : Colors.brown[300])
                  : theme.colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: rank <= 3 
                      ? Colors.white 
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transactionTypeName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${isIncome ? '+' : '-'}${NumberFormat('#,###').format(item.amount.toInt())}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
