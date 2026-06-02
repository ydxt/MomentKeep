import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class ShoppingCardPage extends ConsumerStatefulWidget {
  final String? userId;
  final bool selectMode;
  final List<Map<String, dynamic>>? selectedShoppingCards;

  const ShoppingCardPage({super.key, this.userId, this.selectMode = false, this.selectedShoppingCards});

  @override
  ConsumerState<ShoppingCardPage> createState() => _ShoppingCardPageState();
}

class _ShoppingCardPageState extends ConsumerState<ShoppingCardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _availableCards = [];
  List<Map<String, dynamic>> _usedCards = [];
  List<Map<String, dynamic>> _expiredCards = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> _selectedShoppingCards = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.selectedShoppingCards != null) {
      _selectedShoppingCards = widget.selectedShoppingCards!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShoppingCardData();
    });
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'active':
        return '可用';
      case 'used':
        return '已使用';
      case 'expired':
        return '已过期';
      case 'inactive':
        return '未激活';
      default:
        return status;
    }
  }

  Map<String, dynamic> _shoppingCardToMap(ShoppingCard card) {
    return {
      'id': card.id,
      'card_no': card.cardNo,
      'user_id': card.userId ?? '',
      'name': card.name,
      'amount': card.totalAmount,
      'balance': card.balance,
      'validity': card.validTo != null ? card.validTo!.toIso8601String().split('T')[0] : '永久',
      'status': _mapStatus(card.status),
      'type': '电子卡',
      'created_at': card.createdAt.millisecondsSinceEpoch,
      'updated_at': card.updatedAt.millisecondsSinceEpoch,
    };
  }

  Future<void> _loadShoppingCardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = widget.userId ?? 'default_user';
      final productDb = ProductDatabaseService();
      final allCards = await productDb.getAllShoppingCards(userId: userId);

      final now = DateTime.now();

      _availableCards = [];
      _usedCards = [];
      _expiredCards = [];

      for (var card in allCards) {
        var status = card.status;
        if (card.validTo != null && card.validTo!.isBefore(now) && status == 'active') {
          status = 'expired';
        }

        final map = _shoppingCardToMap(card);
        map['status'] = _mapStatus(status);

        final displayStatus = map['status'] as String;
        if (displayStatus == '可用') {
          _availableCards.add(map);
        } else if (displayStatus == '已使用') {
          _usedCards.add(map);
        } else if (displayStatus == '已过期') {
          _expiredCards.add(map);
        }
      }
    } catch (e) {
      debugPrint('加载购物卡数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        actions: [
          if (!widget.selectMode)
            IconButton(
              icon: Icon(Icons.add_card, color: theme.colorScheme.primary),
              onPressed: () => _showRechargeDialog(),
            ),
          if (widget.selectMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedShoppingCards);
              },
              child: Text('确认', style: TextStyle(color: theme.colorScheme.primary)),
            ),
        ],
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
      body: _isLoading
          ? _buildLoadingState(theme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCardList(_availableCards, theme),
                _buildCardList(_usedCards, theme),
                _buildCardList(_expiredCards, theme),
              ],
            ),
    );
  }

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

  Widget _buildCardItem(Map<String, dynamic> card, ThemeData theme) {
    final isAvailable = card['status'] == '可用';
    final isSelected = _selectedShoppingCards.any((item) => item['id'] == card['id']);
    return GestureDetector(
      onTap: () {
        if (isAvailable && widget.selectMode) {
          setState(() {
            if (isSelected) {
              _selectedShoppingCards.removeWhere((item) => item['id'] == card['id']);
            } else {
              _selectedShoppingCards.add(card);
            }
          });
        } else {
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
                          color: isAvailable ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.outlineVariant.withOpacity(0.2),
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
                    '¥${card['amount']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '余额: ¥${card['balance'] ?? card['amount']}',
                    style: TextStyle(
                      color: isAvailable ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 14,
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
                  Text(
                    '卡号: ${card['card_no']}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTraceabilityInfo(card, theme),
            ],
          ),
        ),
      ),
    );
  }

  void _showRechargeDialog() {
    final cardNoController = TextEditingController();
    final passwordController = TextEditingController();
    final theme = ref.read(currentThemeProvider);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('充值购物卡', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cardNoController,
                decoration: InputDecoration(
                  labelText: '卡号',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '密码',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () async {
                final cardNo = cardNoController.text.trim();
                final password = passwordController.text.trim();

                if (cardNo.isEmpty || password.isEmpty) {
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(SnackBar(content: Text('请输入卡号和密码')));
                  return;
                }

                try {
                  final productDb = ProductDatabaseService();
                  final card = await productDb.getShoppingCardByNo(cardNo);

                  if (card == null) {
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(SnackBar(content: Text('卡号不存在')));
                    return;
                  }

                  if (card.password != password) {
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(SnackBar(content: Text('密码错误')));
                    return;
                  }

                  if (card.userId != null && card.userId!.isNotEmpty) {
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(SnackBar(content: Text('该购物卡已被绑定')));
                    return;
                  }

                  final userId = widget.userId ?? 'default_user';
                  await productDb.activateShoppingCard(card.id!, userId);

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(SnackBar(content: Text('充值成功！已绑定购物卡: ${card.name}')));

                  _loadShoppingCardData();
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(SnackBar(content: Text('充值失败: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text('确认充值'),
            ),
          ],
        );
      },
    );
  }

  void _showTransactionHistory(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text('交易记录', style: TextStyle(color: theme.colorScheme.onBackground)),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTransactionHistory(card['id']),
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
                Navigator.pop(dialogContext);
              },
              child: Text('关闭', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getTransactionHistory(dynamic cardId) async {
    try {
      final productDb = ProductDatabaseService();
      final int id = cardId is int ? cardId : int.tryParse(cardId.toString()) ?? 0;
      final transactions = await productDb.getShoppingCardTransactions(id);
      return transactions
          .map((t) => {
                'id': t.id,
                'description': t.description ?? '',
                'amount': t.amount,
                'type': t.type == 'consume' ? '消费' : t.type == 'recharge' ? '充值' : '退款',
                'transactionType': t.type == 'consume' ? '支出' : '收入',
                'created_at': t.createdAt.millisecondsSinceEpoch,
                'relatedId': t.orderId,
              })
          .toList();
    } catch (e) {
      debugPrint('获取交易记录失败: $e');
      return [];
    }
  }

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
                  '${transaction['transactionType'] == '收入' ? '+' : '-'}¥${transaction['amount']}',
                  style: TextStyle(
                    color: transaction['transactionType'] == '收入' ? theme.colorScheme.primary : theme.colorScheme.error,
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
                  Icon(
                    Icons.person_outline,
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
                  Icon(
                    Icons.note_outlined,
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
                  Icon(
                    Icons.access_time_outlined,
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
                Icon(
                  Icons.receipt_outlined,
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
