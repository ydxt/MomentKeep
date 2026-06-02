import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/product_database_service.dart';

class CustomerServicePage extends ConsumerStatefulWidget {
  final int? productId;
  final String? productName;

  const CustomerServicePage({
    super.key,
    this.productId,
    this.productName,
  });

  @override
  ConsumerState<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends ConsumerState<CustomerServicePage> {
  final DatabaseService _databaseService = DatabaseService();
  final ProductDatabaseService _productDatabaseService = ProductDatabaseService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  String _currentUserId = '';
  
  // 智能客服常见问题
  final List<Map<String, String>> _faqList = [
    {
      'question': '如何查看订单状态？',
      'answer': '您可以在"我的订单"页面查看所有订单的实时状态，包括待付款、待发货、已发货、运输中等状态。',
    },
    {
      'question': '如何申请退款？',
      'answer': '在订单详情页点击"申请售后"，选择退款类型和原因，提交申请后商家会在24小时内处理。',
    },
    {
      'question': '虚拟商品如何使用？',
      'answer': '购买虚拟商品后，您可以在"卡密中心"查看卡密信息和使用说明。部分商品会自动激活权益。',
    },
    {
      'question': '如何联系人工客服？',
      'answer': '如需人工客服帮助，请在下方输入框输入您的问题，我们会尽快为您转接人工客服。',
    },
    {
      'question': '积分如何获取和使用？',
      'answer': '您可以通过签到、购物等方式获取积分。积分可用于兑换商品或抵扣现金，具体规则请查看积分商城。',
    },
    {
      'question': '物流信息不更新怎么办？',
      'answer': '物流信息可能会有延迟，建议您等待1-2天。如长时间未更新，请联系物流公司或申请售后处理。',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initUserId();
  }

  Future<void> _initUserId() async {
    final userId = await _databaseService.getCurrentUserId() ?? 'default_user';
    setState(() {
      _currentUserId = userId;
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 加载历史消息（从数据库或本地存储）
      // 这里先使用模拟数据，后续可以接入真实数据库
      if (_messages.isEmpty) {
        _addSystemMessage('您好！我是智能客服助手，很高兴为您服务。请问有什么可以帮助您的吗？');
        _addSystemMessage('您可以直接输入问题，或者点击下方常见问题快速获取答案。');
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addSystemMessage(String content) {
    setState(() {
      _messages.add({
        'type': 'system',
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add({
        'type': 'user',
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _addBotMessage(String content) {
    setState(() {
      _messages.add({
        'type': 'bot',
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// 智能客服回答逻辑
  String _getBotAnswer(String userQuestion) {
    final question = userQuestion.toLowerCase();
    
    // 关键词匹配
    if (question.contains('订单') || question.contains('物流')) {
      return '关于订单和物流的问题，您可以在"我的订单"页面查看详细信息。如需帮助，请点击下方的"转人工客服"按钮。';
    }
    
    if (question.contains('退款') || question.contains('退货')) {
      return '退款申请流程：\n1. 进入订单详情页\n2. 点击"申请售后"\n3. 选择退款类型\n4. 填写原因并提交\n\n商家会在24小时内审核您的申请。';
    }
    
    if (question.contains('积分') || question.contains('余额')) {
      return '您可以在个人中心查看积分和余额信息。积分可通过签到、购物等方式获取，用于兑换商品或抵扣现金。';
    }
    
    if (question.contains('虚拟') || question.contains('卡密')) {
      return '虚拟商品购买后，卡密信息会保存在"卡密中心"。部分商品会自动激活权益，无需手动操作。';
    }
    
    if (question.contains('人工') || question.contains('转接')) {
      return '正在为您转接人工客服，请稍候...我们的客服工作时间为9:00-18:00。';
    }
    
    // FAQ匹配
    for (var faq in _faqList) {
      if (question.contains(faq['question']!.substring(0, 4))) {
        return faq['answer']!;
      }
    }
    
    return '感谢您的咨询。您的问题我已记录，会尽快为您处理。如需紧急帮助，请拨打客服电话：400-123-4567。';
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    // 添加用户消息
    _addUserMessage(message);
    _messageController.clear();

    // 模拟智能客服响应延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 获取智能回复
    final botAnswer = _getBotAnswer(message);
    _addBotMessage(botAnswer);

    setState(() {
      _isSending = false;
    });
  }

  void _showFaqDialog() {
    final theme = ref.read(currentThemeProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.background,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '常见问题',
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              itemCount: _faqList.length,
              separatorBuilder: (context, index) => Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
              itemBuilder: (context, index) {
                final faq = _faqList[index];
                return ListTile(
                  title: Text(
                    faq['question']!,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {
                    Navigator.pop(context);
                    _addUserMessage(faq['question']!);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _addBotMessage(faq['answer']!);
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '客服中心',
              style: TextStyle(color: theme.colorScheme.onBackground),
            ),
            if (widget.productName != null)
              Text(
                '商品：${widget.productName}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            onPressed: _showFaqDialog,
            tooltip: '常见问题',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message, theme);
                    },
                  ),
          ),
          
          // 快捷操作栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickActionChip('订单查询', theme),
                        const SizedBox(width: 8),
                        _buildQuickActionChip('退款申请', theme),
                        const SizedBox(width: 8),
                        _buildQuickActionChip('物流跟踪', theme),
                        const SizedBox(width: 8),
                        _buildQuickActionChip('转人工', theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 输入框
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: '请输入您的问题...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      filled: true,
                      fillColor: theme.colorScheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.send, color: theme.colorScheme.primary),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, ThemeData theme) {
    final type = message['type'] as String;
    final content = message['content'] as String;
    final timestamp = message['timestamp'] as int;
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (type == 'system') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Icon(Icons.support_agent, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (type == 'user') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 40),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 14),
                ),
              ),
            ),
            Text(
              timeStr,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      // bot
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Icon(Icons.smart_toy, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildQuickActionChip(String label, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        _addUserMessage(label);
        Future.delayed(const Duration(milliseconds: 500), () {
          final answer = _getBotAnswer(label);
          _addBotMessage(answer);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
