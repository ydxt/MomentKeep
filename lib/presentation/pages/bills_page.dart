import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 账单页面
class BillsPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();
  
  /// 当前用户ID
  String _userId = 'default_user';
  
  /// 分组后的账单数据，格式：{日期: [账单明细列表]}
  Map<String, List<BillItem>> _groupedBillItems = {};
  
  /// 账单统计数据
  Map<String, dynamic> _statistics = {
    'balance': 0,
    'total_income': 0,
    'total_expense': 0,
  };
  
  /// 筛选条件
  Map<String, dynamic> _filters = {
    'startDate': DateTime.now().subtract(const Duration(days: 30)),
    'endDate': DateTime.now(),
    'type': null, // 'income' 或 'expense' 或 null
    'transactionType': null,
  };
  
  /// 搜索关键词
  String _searchKeyword = '';
  
  /// 是否显示筛选窗口
  bool _showFilterDialog = false;
  
  /// 交易类型映射
  final Map<String, String> _transactionTypeMap = {
    'reward': '获得奖励',
    'exchange': '兑换商品',
    'refund': '积分退款',
    'daily_checkin': '每日打卡',
    'habit_completed': '习惯完成',
    'pomodoro_completed': '番茄钟完成',
  };
  
  /// 加载数据
  Future<void> _loadData() async {
    try {
      // 获取当前用户ID
      _userId = await _databaseService.getCurrentUserId() ?? 'default_user';
      
      // 获取账单统计
      final statistics = await _databaseService.getBillStatistics(
        _userId,
        startDate: _filters['startDate'],
        endDate: _filters['endDate'],
      );
      
      // 获取账单明细
      final billItems = await _databaseService.getBillItems(
        _userId,
        startDate: _filters['startDate'],
        endDate: _filters['endDate'],
        type: _filters['type'],
        transactionType: _filters['transactionType'],
      );
      
      // 搜索筛选
      final filteredItems = _searchKeyword.isEmpty
          ? billItems
          : billItems.where((item) => item.description.contains(_searchKeyword)).toList();
      
      // 分组处理
      final groupedItems = <String, List<BillItem>>{};
      for (final item in filteredItems) {
        final date = DateFormat('yyyy-MM-dd').format(item.createdAt);
        if (!groupedItems.containsKey(date)) {
          groupedItems[date] = [];
        }
        groupedItems[date]!.add(item);
      }
      
      setState(() {
        _statistics = statistics;
        _groupedBillItems = groupedItems;
      });
    } catch (e) {
      debugPrint('加载账单数据失败: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  /// 显示筛选窗口
  void _showFilterBottomSheet() {
    setState(() {
      _showFilterDialog = true;
    });
  }
  
  /// 关闭筛选窗口
  void _closeFilterBottomSheet() {
    setState(() {
      _showFilterDialog = false;
    });
  }
  
  /// 应用筛选条件
  void _applyFilters() {
    _closeFilterBottomSheet();
    _loadData();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: GestureDetector(
        onTap: () {
          // 点击空白处关闭键盘
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceSection(theme),
              const SizedBox(height: 24),
              _buildSearchFilterSection(theme),
              const SizedBox(height: 20),
              _buildBillList(theme),
              if (_groupedBillItems.isEmpty)
                _buildEmptyState(theme),
              if (isMobile)
                const SizedBox(height: 80), // 为底部导航预留空间
            ],
          ),
        ),
      ),
      bottomSheet: _showFilterDialog ? _buildFilterBottomSheet(theme) : null,
    );
  }
  
  /// 构建顶部AppBar
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Text(
        '星星账单',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
  
  /// 构建余额显示区域
  Widget _buildBalanceSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        children: [
          Text(
            '当前星星余额',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '✨',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Text(
                NumberFormat('#,###').format(_statistics['balance']),
                style: TextStyle(
                  fontSize: 40,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                theme: theme,
                title: '本期获得',
                value: _statistics['total_income'],
                color: theme.colorScheme.primary,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outline,
              ),
              _buildStatItem(
                theme: theme,
                title: '本期支出',
                value: _statistics['total_expense'],
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建统计项
  Widget _buildStatItem({
    required ThemeData theme,
    required String title,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          NumberFormat('#,###').format(value),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  /// 构建搜索筛选区域
  Widget _buildSearchFilterSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: TextField(
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: '搜索账单...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKeyword = value;
                    });
                    _loadData();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showFilterBottomSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Text(
                      '全部账单',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.filter_list,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                theme: theme,
                label: '全部',
                isSelected: _filters['type'] == null,
                onTap: () {
                  setState(() {
                    _filters['type'] = null;
                  });
                  _loadData();
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                theme: theme,
                label: '收入',
                isSelected: _filters['type'] == 'income',
                onTap: () {
                  setState(() {
                    _filters['type'] = 'income';
                  });
                  _loadData();
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                theme: theme,
                label: '支出',
                isSelected: _filters['type'] == 'expense',
                onTap: () {
                  setState(() {
                    _filters['type'] = 'expense';
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// 构建筛选芯片
  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  /// 构建账单列表
  Widget _buildBillList(ThemeData theme) {
    // 按日期降序排序
    final sortedDates = _groupedBillItems.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final date in sortedDates) ...[
          _buildDateHeader(date, theme),
          const SizedBox(height: 12),
          for (final item in _groupedBillItems[date]!) ...[
            _buildBillItem(item, theme),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
  
  /// 构建日期标题
  Widget _buildDateHeader(String date, ThemeData theme) {
    return Text(
      date,
      style: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
  
  /// 构建账单明细项
  Widget _buildBillItem(BillItem item, ThemeData theme) {
    final isIncome = item.type == 'income';
    final transactionTypeName = _transactionTypeMap[item.transactionType] ?? item.transactionType;
    final primaryColor = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: primaryColor.withOpacity(0.1),
                      ),
                      child: Icon(
                        isIncome ? Icons.add : Icons.remove,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transactionTypeName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('HH:mm').format(item.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 根据交易类型和描述判断是积分支付还是金钱支付
          Text(
            '${_isPointsPayment(item) ? (isIncome ? '✨+' : '✨-') : (isIncome ? '¥+' : '¥-')}${NumberFormat('#,###').format(item.amount)}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.receipt_long,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账单记录',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始使用星星商店来赚取和使用积分吧',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建筛选底部弹窗
  Widget _buildFilterBottomSheet(ThemeData theme) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _closeFilterBottomSheet,
                  child: Text(
                    '取消',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '筛选账单',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _applyFilters,
                  child: Text(
                    '确定',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.colorScheme.outline),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '时间范围',
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
                        child: _buildDatePicker(
                          theme: theme,
                          label: '开始日期',
                          value: _filters['startDate'],
                          onChanged: (date) {
                            setState(() {
                              _filters['startDate'] = date;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatePicker(
                          theme: theme,
                          label: '结束日期',
                          value: _filters['endDate'],
                          onChanged: (date) {
                            setState(() {
                              _filters['endDate'] = date;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '类型',
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
                        child: _buildRadioButton(
                          theme: theme,
                          label: '全部',
                          value: null,
                          groupValue: _filters['type'],
                          onChanged: (value) {
                            setState(() {
                              _filters['type'] = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildRadioButton(
                          theme: theme,
                          label: '收入',
                          value: 'income',
                          groupValue: _filters['type'],
                          onChanged: (value) {
                            setState(() {
                              _filters['type'] = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildRadioButton(
                          theme: theme,
                          label: '支出',
                          value: 'expense',
                          groupValue: _filters['type'],
                          onChanged: (value) {
                            setState(() {
                              _filters['type'] = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '交易类型',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransactionTypeFilter(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建日期选择器
  Widget _buildDatePicker({
    required ThemeData theme,
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: theme,
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('yyyy-MM-dd').format(value),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建单选按钮
  Widget _buildRadioButton({
    required ThemeData theme,
    required String label,
    required String? value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        onChanged(value);
      },
      child: Row(
        children: [
          Radio<String?>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.selected)) {
                return theme.colorScheme.primary;
              }
              return theme.colorScheme.outline;
            }),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建交易类型筛选
  Widget _buildTransactionTypeFilter(ThemeData theme) {
    final transactionTypes = [
      {'value': null, 'label': '全部'},
      {'value': 'reward', 'label': '获得奖励'},
      {'value': 'exchange', 'label': '兑换商品'},
      {'value': 'refund', 'label': '积分退款'},
      {'value': 'daily_checkin', 'label': '每日打卡'},
      {'value': 'habit_completed', 'label': '习惯完成'},
      {'value': 'pomodoro_completed', 'label': '番茄钟完成'},
    ];
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final type in transactionTypes)
          GestureDetector(
            onTap: () {
              setState(() {
                _filters['transactionType'] = type['value'];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _filters['transactionType'] == type['value'] 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: _filters['transactionType'] == type['value'] 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                type['label']!,
                style: TextStyle(
                  color: _filters['transactionType'] == type['value'] 
                      ? theme.colorScheme.onPrimary 
                      : theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  /// 判断交易是否为积分支付
  bool _isPointsPayment(BillItem item) {
    // 检查交易类型
    if (item.transactionType == 'reward' || 
        item.transactionType == 'exchange' || 
        item.transactionType == 'refund' || 
        item.transactionType == 'daily_checkin' || 
        item.transactionType == 'habit_completed' || 
        item.transactionType == 'pomodoro_completed') {
      return true;
    }
    
    // 检查描述中是否包含积分相关信息
    if (item.description.contains('积分') || 
        item.description.contains('星星') || 
        item.description.contains('✨')) {
      return true;
    }
    
    // 默认为金钱支付
    return false;
  }
}
