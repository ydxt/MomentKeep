import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:flutter/foundation.dart';

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
      
      // 从数据库获取用户积分
      final points = await _databaseService.getUserPoints(userId);
      debugPrint('从数据库获取的积分: $points');
      
      // 从用户数据库获取会员等级
      final userData = await _userDatabaseService.getUserById(userId);
      final memberLevel = userData != null && userData.containsKey('member_level') ? userData['member_level'] : 0;
      debugPrint('从数据库获取的会员等级: $memberLevel');
      
      // 根据会员等级计算等级名称和升级所需积分
      _calculateMemberLevel(memberLevel, points);
      
      // 模拟积分明细数据（后续应替换为真实数据库查询）
      _pointsHistory = await _getPointsHistory(userId);
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
  
  // 获取积分明细数据
  Future<List<Map<String, dynamic>>> _getPointsHistory(String userId) async {
    try {
      // 从数据库获取真实的积分记录
      final billItems = await _databaseService.getBillItems(userId);
      
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
            
            // 积分明细标题
            Text(
              '积分明细',
              style: TextStyle(
                color: theme.colorScheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                history['title'],
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
}
