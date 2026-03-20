import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/presentation/pages/points_statistics_page.dart';

class MemberLevelPage extends ConsumerStatefulWidget {
  final String? userId;
  
  const MemberLevelPage({super.key, this.userId});

  @override
  ConsumerState<MemberLevelPage> createState() => _MemberLevelPageState();
}

class _MemberLevelPageState extends ConsumerState<MemberLevelPage> {
  // 真实数据状态
  String _currentLevel = '普通会员';
  int _currentPoints = 0;
  int _nextLevelPoints = 0;
  int _levelProgress = 0;
  List<Map<String, dynamic>> _pointsHistory = [];
  bool _isLoading = true;
  
  // 筛选状态
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _filterType; // 'income', 'expense', null
  String? _filterTransactionType;
  String? _searchQuery;
  String _selectedTimeRange = 'all'; // all, today, week, month, year, custom
  bool _showFilterBar = true;
  
  // 买家信用积分
  int? _buyerCreditScore;
  String? _buyerCreditLevel;
  
  // 卖家信用积分
  int? _sellerCreditScore;
  String? _sellerCreditLevel;
  
  // 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();
  final UserDatabaseService _userDatabaseService = UserDatabaseService();
  
  @override
  void initState() {
    super.initState();
    // 延迟加载数据，避免在构建过程中调用异步方法
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMemberData();
    });
  }
  
  // 加载会员数据
  Future<void> _loadMemberData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 使用从构造函数传递过来的userId，如果为null则使用默认值
      final userId = widget.userId ?? 'default_user';
      debugPrint('使用的用户ID: $userId');
      
      // 首先修复积分不一致的问题
      await _databaseService.fixHistoricalTransactionTypes(userId);
      await _databaseService.recalculateAndFixPoints(userId);
      
      // 首先获取所有积分明细（不应用任何筛选）
      final allBillItems = await _databaseService.getBillItems(userId);
      
      // 直接从积分明细计算总和来验证
      int calculatedTotalIncome = 0;
      int calculatedTotalExpense = 0;
      for (final item in allBillItems) {
        if (item.type == 'income') {
          calculatedTotalIncome += item.amount.round();
        } else {
          calculatedTotalExpense += item.amount.round();
        }
      }
      final calculatedPoints = calculatedTotalIncome - calculatedTotalExpense;
      debugPrint('从积分明细直接计算 - 收入: $calculatedTotalIncome, 支出: $calculatedTotalExpense, 总计: $calculatedPoints');
      
      // 从数据库获取用户积分
      final points = await _databaseService.getUserPoints(userId);
      debugPrint('从数据库获取的积分: $points');
      
      // 验证积分是否一致，如果不一致，再次修复
      if (points.round() != calculatedPoints) {
        debugPrint('积分不一致！数据库: ${points.round()}, 明细计算: $calculatedPoints，再次修复');
        // 使用DatabaseService的直接更新方法
        await _databaseService.updatePointsDirectly(userId, calculatedPoints);
      }
      
      // 重新获取确保数据一致性
      final finalPoints = await _databaseService.getUserPoints(userId);
      debugPrint('最终确认的积分: $finalPoints');
      
      // 从用户数据库获取会员等级
      final userData = await _userDatabaseService.getUserById(userId);
      final memberLevel = userData != null && userData.containsKey('member_level') ? userData['member_level'] : 0;
      debugPrint('从数据库获取的会员等级: $memberLevel');
      
      // 加载买家信用积分
      final buyerCredit = await _userDatabaseService.getBuyerCreditScore(userId);
      
      // 加载卖家信用积分
      final sellerCredit = await _userDatabaseService.getSellerCreditScore(userId);
      
      // 根据会员等级计算等级名称和升级所需积分
      _calculateMemberLevel(memberLevel, finalPoints);
      
      // 获取积分明细数据（应用筛选条件）
      _pointsHistory = await _getPointsHistory(userId);
      
      setState(() {
        _buyerCreditScore = buyerCredit?.creditScore;
        _buyerCreditLevel = buyerCredit?.creditLevel;
        _sellerCreditScore = sellerCredit?.creditScore;
        _sellerCreditLevel = sellerCredit?.creditLevel;
      });
    } catch (e) {
      debugPrint('加载会员数据失败: $e');
      // 如果获取失败，使用默认值
      _currentPoints = 0;
      _currentLevel = '普通会员';
      _nextLevelPoints = 5000;
      _levelProgress = 0;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 根据会员等级计算等级名称和升级所需积分
  void _calculateMemberLevel(int memberLevel, double points) {
    // 设置当前积分，转换为整数
    _currentPoints = points.round();
    
    // 根据会员等级设置等级名称和升级所需积分
    switch (memberLevel) {
      case 0:
        _currentLevel = '普通会员';
        _nextLevelPoints = 5000;
        break;
      case 1:
        _currentLevel = 'VIP会员';
        _nextLevelPoints = 20000;
        break;
      case 2:
        _currentLevel = '黄金会员';
        _nextLevelPoints = 50000;
        break;
      case 3:
        _currentLevel = '铂金会员';
        _nextLevelPoints = 100000;
        break;
      case 4:
        _currentLevel = '钻石会员';
        _nextLevelPoints = 0; // 最高等级
        break;
      default:
        _currentLevel = '普通会员';
        _nextLevelPoints = 5000;
    }
    
    // 计算升级进度
    if (_nextLevelPoints > 0) {
      _levelProgress = (_currentPoints / _nextLevelPoints * 100).round();
      // 限制进度在0-100之间
      if (_levelProgress > 100) {
        _levelProgress = 100;
      } else if (_levelProgress < 0) {
        _levelProgress = 0;
      }
    } else {
      _levelProgress = 100; // 最高等级进度为100%
    }
  }
  
  // 计算筛选范围内的统计数据
  Map<String, double> _calculateFilteredStats(List<Map<String, dynamic>> history) {
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final item in history) {
      final isIncome = item['type'] == 'income';
      final pointsStr = item['points'] as String;
      
      // 正确解析积分值，处理 ✨+ 和 ✨- 前缀
      double points = 0;
      if (pointsStr.contains('+')) {
        final numStr = pointsStr.replaceAll(RegExp(r'[^0-9]'), '');
        points = double.tryParse(numStr) ?? 0;
      } else if (pointsStr.contains('-')) {
        final numStr = pointsStr.replaceAll(RegExp(r'[^0-9]'), '');
        points = -(double.tryParse(numStr) ?? 0);
      }
      
      if (isIncome) {
        totalIncome += points.abs();
      } else {
        totalExpense += points.abs();
      }
    }
    
    return {
      'income': totalIncome,
      'expense': totalExpense,
      'net': totalIncome - totalExpense,
    };
  }

  // 获取积分明细数据
  Future<List<Map<String, dynamic>>> _getPointsHistory(String userId) async {
    try {
      // 从数据库获取真实的积分记录
      final billItems = await _databaseService.getBillItems(
        userId,
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        type: _filterType,
        transactionType: _filterTransactionType,
        searchQuery: _searchQuery,
      );
      
      // 将BillItem转换为适合积分明细页面显示的格式
      return billItems.map((item) {
        final isIncome = item.type == 'income';
        final dateStr = '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}';
        final points = item.amount.round();
        return {
          'id': item.id,
          'title': item.description,
          'points': isIncome ? '✨+$points' : '✨-$points',
          'date': dateStr,
          'type': item.type,
        };
      }).toList()
      // 按日期降序排序
      ..sort((a, b) {
        final dateA = a['date'] as String;
        final dateB = b['date'] as String;
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint('获取积分明细失败: $e');
      return [];
    }
  }
  
  // 应用时间范围筛选
  void _applyTimeRange(String range) {
    setState(() {
      _selectedTimeRange = range;
      final now = DateTime.now();
      
      switch (range) {
        case 'today':
          _filterStartDate = DateTime(now.year, now.month, now.day);
          _filterEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          _filterStartDate = now.subtract(Duration(days: now.weekday - 1));
          _filterStartDate = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
          _filterEndDate = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
          _filterEndDate = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
          break;
        case 'month':
          _filterStartDate = DateTime(now.year, now.month, 1);
          _filterEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'year':
          _filterStartDate = DateTime(now.year, 1, 1);
          _filterEndDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case 'all':
        default:
          _filterStartDate = null;
          _filterEndDate = null;
          break;
      }
    });
    _refreshPointsHistory();
  }
  
  // 选择自定义日期范围
  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _selectedTimeRange = 'custom';
        _filterStartDate = picked.start;
        _filterEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _refreshPointsHistory();
    }
  }
  
  // 刷新积分明细
  Future<void> _refreshPointsHistory() async {
    final userId = widget.userId ?? 'default_user';
    final history = await _getPointsHistory(userId);
    setState(() {
      _pointsHistory = history;
    });
  }
  
  // 清除所有筛选
  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _filterType = null;
      _filterTransactionType = null;
      _searchQuery = null;
      _selectedTimeRange = 'all';
    });
    _refreshPointsHistory();
  }
  
  // 打开收支统计页面
  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PointsStatisticsPage(userId: widget.userId ?? 'default_user'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        foregroundColor: theme.colorScheme.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('会员等级 / 积分', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isLoading ? _buildLoadingState(theme) : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 会员等级卡片
            _buildMemberLevelCard(theme),
            const SizedBox(height: 20),
            
            // 积分明细标题和操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '积分明细',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showFilterBar ? Icons.filter_alt_off : Icons.filter_alt,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilterBar = !_showFilterBar;
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: _openStatistics,
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('收支统计'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 筛选栏
            if (_showFilterBar) ...[
              _buildFilterBar(theme),
              const SizedBox(height: 12),
            ],
            
            // 筛选范围内统计摘要
            _buildFilteredStatsSummary(theme),
            const SizedBox(height: 12),
            
            // 积分明细列表
            _buildPointsHistoryList(theme),
          ],
        ),
      ),
    );
  }

  // 构建加载状态
  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '加载会员数据中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建会员等级卡片
  Widget _buildMemberLevelCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 当前等级
            Text(
              _currentLevel,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 等级图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
              child: Center(
                child: Text(
                  _currentLevel.substring(0, 2),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 积分信息
            Text(
              '✨ $_currentPoints',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 信用积分展示
            if (_buyerCreditScore != null || _sellerCreditScore != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '信用积分',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 买家信用积分
                        if (_buyerCreditScore != null)
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '买家',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_buyerCreditScore',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_buyerCreditLevel != null)
                                  Text(
                                    _buyerCreditLevel!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        
                        // 分隔线
                        if (_buyerCreditScore != null && _sellerCreditScore != null)
                          Container(
                            width: 1,
                            height: 36,
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        
                        // 卖家信用积分
                        if (_sellerCreditScore != null)
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.store,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '卖家',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_sellerCreditScore',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_sellerCreditLevel != null)
                                  Text(
                                    _sellerCreditLevel!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            
            // 升级进度
            Text(
              _nextLevelPoints > 0 
                  ? '距离升级还需 ${(_nextLevelPoints - _currentPoints).isNegative ? '✨' : '✨+'}${(_nextLevelPoints - _currentPoints).abs()}' 
                  : '已是最高等级',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // 进度条
            LayoutBuilder(
              builder: (context, constraints) {
                final progressBarWidth = constraints.maxWidth;
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: progressBarWidth * (_levelProgress / 100),
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned(
                        right: progressBarWidth * (1 - _levelProgress / 100),
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_levelProgress%',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // 等级权益
            Text(
              '等级权益',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 权益列表
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBenefitTag('购物9折', theme),
                _buildBenefitTag('生日礼包', theme),
                _buildBenefitTag('免费配送', theme),
                _buildBenefitTag('专属客服', theme),
                _buildBenefitTag('积分加速', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建权益标签
  Widget _buildBenefitTag(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 14,
        ),
      ),
    );
  }

  // 构建积分明细列表
  Widget _buildPointsHistoryList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pointsHistory.length,
      itemBuilder: (context, index) {
        final history = _pointsHistory[index];
        return _buildPointsHistoryItem(history, theme);
      },
    );
  }

  // 构建积分明细项
  Widget _buildPointsHistoryItem(Map<String, dynamic> history, ThemeData theme) {
    final isIncome = history['type'] == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 标题和日期
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history['title'],
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  history['date'],
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // 积分变化
          Text(
            history['points'],
            style: TextStyle(
              color: isIncome ? theme.colorScheme.primary : theme.colorScheme.error,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建筛选栏
  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索积分记录...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = null;
                        });
                        _refreshPointsHistory();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.isEmpty ? null : value;
              });
              _refreshPointsHistory();
            },
          ),
          const SizedBox(height: 12),
          
          // 时间范围选择
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '时间范围',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeRangeChip('全部', 'all', theme),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('今天', 'today', theme),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('本周', 'week', theme),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('本月', 'month', theme),
                    const SizedBox(width: 8),
                    _buildTimeRangeChip('本年', 'year', theme),
                    const SizedBox(width: 8),
                    _buildCustomTimeRangeChip(theme),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 收支类型筛选
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '收支类型',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip('全部', null, theme, _filterType == null),
                  const SizedBox(width: 8),
                  _buildFilterChip('收入', 'income', theme, _filterType == 'income'),
                  const SizedBox(width: 8),
                  _buildFilterChip('支出', 'expense', theme, _filterType == 'expense'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 清除筛选按钮
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('清除筛选'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建时间范围选择芯片
  Widget _buildTimeRangeChip(String label, String value, ThemeData theme) {
    final isSelected = _selectedTimeRange == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _applyTimeRange(value);
        }
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
    );
  }
  
  // 构建自定义时间范围芯片
  Widget _buildCustomTimeRangeChip(ThemeData theme) {
    final isSelected = _selectedTimeRange == 'custom';
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range, size: 16),
          const SizedBox(width: 4),
          const Text('自定义'),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _selectCustomDateRange();
        }
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
    );
  }
  
  // 构建筛选芯片
  Widget _buildFilterChip(String label, String? value, ThemeData theme, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? value : null;
        });
        _refreshPointsHistory();
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
    );
  }

  // 构建筛选范围内统计摘要
  Widget _buildFilteredStatsSummary(ThemeData theme) {
    final stats = _calculateFilteredStats(_pointsHistory);
    final income = stats['income'] ?? 0;
    final expense = stats['expense'] ?? 0;
    final net = stats['net'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('收入', income, theme.colorScheme.primary, theme),
          _buildStatItem('支出', expense, theme.colorScheme.error, theme),
          _buildStatItem('净收入', net, 
            net >= 0 ? theme.colorScheme.primary : theme.colorScheme.error, theme),
        ],
      ),
    );
  }

  // 构建统计项
  Widget _buildStatItem(String title, double value, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value >= 0 ? '+' : ''}${value.toInt()}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
