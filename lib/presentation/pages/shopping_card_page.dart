import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class ShoppingCardPage extends ConsumerStatefulWidget {
  final String? userId;
  final bool selectMode;
  final List<Map<String, dynamic>>? selectedShoppingCards; // 已选中的购物卡列表
  
  const ShoppingCardPage({super.key, this.userId, this.selectMode = false, this.selectedShoppingCards});

  @override
  ConsumerState<ShoppingCardPage> createState() => _ShoppingCardPageState();
}

class _ShoppingCardPageState extends ConsumerState<ShoppingCardPage> with SingleTickerProviderStateMixin {
  // 标签控制器
  late TabController _tabController;

  // 真实数据状态
  List<Map<String, dynamic>> _availableCards = [];
  List<Map<String, dynamic>> _usedCards = [];
  List<Map<String, dynamic>> _expiredCards = [];
  bool _isLoading = true;
  
  // 选中的购物卡列表（用于多选模式）
  List<Map<String, dynamic>> _selectedShoppingCards = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 初始化已选中的购物卡列表
    if (widget.selectedShoppingCards != null) {
      _selectedShoppingCards = widget.selectedShoppingCards!;
    }
    // 延迟加载数据，避免在构建过程中调用异步方法
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShoppingCardData();
    });
  }
  
  // 检查并更新购物卡的状态
  List<Map<String, dynamic>> _checkAndUpdateCardStatus(List<Map<String, dynamic>> cards) {
    final now = DateTime.now();
    final updatedCards = <Map<String, dynamic>>[];
    
    for (var card in cards) {
      // 创建一个新的Map，而不是直接修改原对象
      final updatedCard = Map<String, dynamic>.from(card);
      final validityDate = DateTime.tryParse(updatedCard['validity']);
      if (validityDate != null && validityDate.isBefore(now) && updatedCard['status'] == '可用') {
        updatedCard['status'] = '已过期';
      }
      updatedCards.add(updatedCard);
    }
    
    return updatedCards;
  }
  
  // 加载购物卡数据
  Future<void> _loadShoppingCardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 使用从构造函数传递过来的userId，如果为null则使用默认值
      final userId = widget.userId ?? 'default_user';
      debugPrint('使用的用户ID: $userId');
      
      // 从数据库获取真实购物卡数据
      final databaseService = DatabaseService();
      var allCards = await databaseService.getUserShoppingCards(userId);
      
      // 检查并更新购物卡的状态
      allCards = _checkAndUpdateCardStatus(allCards);
      
      // 分类购物卡：可用、已使用、已过期
      _availableCards = [];
      _usedCards = [];
      _expiredCards = [];
      
      for (var card in allCards) {
        if (card['status'] == '可用') {
          _availableCards.add(card);
        } else if (card['status'] == '已使用') {
          _usedCards.add(card);
        } else if (card['status'] == '已过期') {
          _expiredCards.add(card);
        }
      }
      
      // 如果没有数据，初始化一些模拟数据用于测试
      if (allCards.isEmpty) {
        final mockCards = [
          {
            'id': '1',
            'name': '50元购物卡',
            'amount': 50,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '电子卡',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '2',
            'name': '100元购物卡',
            'amount': 100,
            'validity': '2023-12-31',
            'status': '可用',
            'type': '电子卡',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '3',
            'name': '200元购物卡',
            'amount': 200,
            'validity': '2023-06-30',
            'status': '已使用',
            'type': '实体卡',
            'used_date': '2023-05-15',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          {
            'id': '4',
            'name': '150元购物卡',
            'amount': 150,
            'validity': '2023-03-31',
            'status': '已过期',
            'type': '实体卡',
            'user_id': userId,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        ];
        
        // 保存模拟数据到数据库
        for (var card in mockCards) {
          await databaseService.database.then((db) async {
            await db.insert('shopping_cards', card);
          });
        }
        
        // 重新分类
        for (var card in mockCards) {
          if (card['status'] == '可用') {
            _availableCards.add(card);
          } else if (card['status'] == '已使用') {
            _usedCards.add(card);
          } else if (card['status'] == '已过期') {
            _expiredCards.add(card);
          }
        }
      }
    } catch (e) {
      debugPrint('加载购物卡数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text('购物卡', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
        actions: widget.selectMode ? [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedShoppingCards);
            },
            child: Text('确认', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ] : [],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(text: '可用 (${_availableCards.length})'),
            Tab(text: '已使用 (${_usedCards.length})'),
            Tab(text: '已过期 (${_expiredCards.length})'),
          ],
        ),
      ),
      body: _isLoading ? _buildLoadingState(theme) : TabBarView(
        controller: _tabController,
        children: [
          // 可用购物卡列表
          _buildCardList(_availableCards, theme),
          // 已使用购物卡列表
          _buildCardList(_usedCards, theme),
          // 已过期购物卡列表
          _buildCardList(_expiredCards, theme),
        ],
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
            '加载购物卡数据中...',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建购物卡列表
  Widget _buildCardList(List<Map<String, dynamic>> cards, ThemeData theme) {
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无购物卡',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _buildCardItem(card, theme);
      },
    );
  }

  // 构建购物卡项
  Widget _buildCardItem(Map<String, dynamic> card, ThemeData theme) {
    final isAvailable = card['status'] == '可用';
    final isSelected = _selectedShoppingCards.any((item) => item['id'] == card['id']);
    return GestureDetector(
      onTap: () {
        if (isAvailable && widget.selectMode) {
          // 多选模式：切换选择状态
          setState(() {
            if (isSelected) {
              _selectedShoppingCards.removeWhere((item) => item['id'] == card['id']);
            } else {
              _selectedShoppingCards.add(card);
            }
          });
        } else {
          // 显示交易记录
          _showTransactionHistory(card);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      card['name'],
                      style: TextStyle(
                        color: isAvailable ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.selectMode && isAvailable) 
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedShoppingCards.add(card);
                              } else {
                                _selectedShoppingCards.removeWhere((item) => item['id'] == card['id']);
                              }
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable 
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : theme.colorScheme.outlineVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          card['status'],
                          style: TextStyle(
                            color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${card['name'].contains('星星') ? '✨' : '¥'}${card['amount']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    card['type'],
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '有效期至: ${card['validity']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  if (card.containsKey('used_date'))
                    Text(
                      '使用日期: ${card['used_date']}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 溯源信息
              _buildTraceabilityInfo(card, theme),
              const SizedBox(height: 12),
              if (isAvailable && !widget.selectMode)
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      _showNotImplemented(theme);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    child: Text('立即使用', style: TextStyle(color: theme.colorScheme.onPrimary)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示功能未实现提示
  void _showNotImplemented(ThemeData theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('该功能尚未实现', style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 显示交易记录
  void _showTransactionHistory(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('交易记录', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTransactionHistory(card['id'], card['name'], 'shopping_card'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('加载交易记录失败', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Center(
                    child: Text('暂无交易记录', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionItem(transaction, theme);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  // 获取交易记录
  Future<List<Map<String, dynamic>>> _getTransactionHistory(String cardId, String cardName, String type) async {
    final databaseService = DatabaseService();
    final userId = widget.userId ?? 'default_user';
    final billItems = await databaseService.getBillItems(
      userId,
    );
    // 转换BillItem为Map，并过滤出与当前购物卡相关的交易记录
    return billItems
        .where((item) {
          // 检查交易描述中是否包含当前购物卡的ID
          // 由于交易记录的relatedId是订单ID，我们需要通过描述来匹配
          return item.description != null && item.description.contains('购物卡:') && item.description.contains(cardId);
        })
        .map((item) => {
          'id': item.id,
          'description': item.description,
          'amount': item.amount,
          'type': item.type,
          'transactionType': item.transactionType,
          'created_at': item.createdAt.millisecondsSinceEpoch,
          'relatedId': item.relatedId,
        })
        .toList();
  }

  // 构建交易记录项
  Widget _buildTransactionItem(Map<String, dynamic> transaction, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction['description'] ?? '无描述',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${transaction['transactionType'] == '收入' ? '+' : '-' }¥${transaction['amount']}',
                  style: TextStyle(
                    color: transaction['transactionType'] == '收入' 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${transaction['type']} | ${DateTime.fromMillisecondsSinceEpoch(transaction['created_at']).toString().substring(0, 19)}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建溯源信息
  Widget _buildTraceabilityInfo(Map<String, dynamic> card, ThemeData theme) {
    final fromUserName = card['from_user_name'] as String?;
    final reason = card['reason'] as String?;
    final usedAt = card['used_at'] as int?;
    final usedOrderId = card['used_order_id'] as String?;
    
    if ((fromUserName == null || fromUserName.isEmpty) && (reason == null || reason.isEmpty)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '溯源信息',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (fromUserName != null && fromUserName.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.person_outline, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '来源: $fromUserName',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (reason != null && reason.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.note_outlined, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '原因: $reason',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (usedAt != null) 
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, 
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '使用时间: ${DateTime.fromMillisecondsSinceEpoch(usedAt).toString().substring(0, 19)}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (usedOrderId != null && usedOrderId.isNotEmpty) 
            Row(
              children: [
                Icon(Icons.receipt_outlined, 
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '使用订单: $usedOrderId',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
