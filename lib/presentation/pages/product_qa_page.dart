import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';

class ProductQAPage extends ConsumerStatefulWidget {
  final StarProduct product;

  const ProductQAPage({super.key, required this.product});

  @override
  ConsumerState<ProductQAPage> createState() => _ProductQAPageState();
}

class _ProductQAPageState extends ConsumerState<ProductQAPage> {
  final ProductDatabaseService _databaseService = ProductDatabaseService();
  final DatabaseService _authService = DatabaseService();
  
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _totalQuestions = 0;
  int _answeredCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (widget.product.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final questions = await _databaseService.getProductQuestions(
        productId: widget.product.id!,
        limit: 50,
      );

      final answeredCount = questions.where((q) => q['is_answered'] == 1).length;

      if (mounted) {
        setState(() {
          _questions = questions;
          _totalQuestions = questions.length;
          _answeredCount = answeredCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载问题失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载问题失败，请重试')),
        );
      }
    }
  }

  void _showAskQuestionDialog() {
    final questionController = TextEditingController();
    final theme = ref.read(currentThemeProvider);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.background,
          title: Text(
            '提问',
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: '请输入您的问题',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  hintText: '例如：这个商品的材质是什么？',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final question = questionController.text.trim();
                      if (question.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('请输入问题内容')),
                        );
                        return;
                      }

                      setState(() {
                        _isSubmitting = true;
                      });

                      try {
                        final userId = await _authService.getCurrentUserId() ?? 'default_user';
                        final userName = userId;

                        await _databaseService.insertQuestion(
                          productId: widget.product.id!,
                          userId: userId,
                          userName: userName,
                          question: question,
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('提问成功！等待商家回答')),
                        );

                        await _loadQuestions();
                      } catch (e) {
                        debugPrint('提问失败: $e');
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('提问失败，请重试')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSubmitting = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text('提交'),
            ),
          ],
        );
      },
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '商品问答',
          style: TextStyle(color: theme.colorScheme.onBackground),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_comment, color: theme.colorScheme.primary),
            onPressed: _showAskQuestionDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            )
          : _questions.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _loadQuestions,
                  color: theme.colorScheme.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      return _buildQuestionCard(question, theme);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.question_answer_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无问题',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '成为第一个提问的人吧',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAskQuestionDialog,
            icon: Icon(Icons.add_comment),
            label: Text('我要提问'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, ThemeData theme) {
    final isAnswered = question['is_answered'] == 1;
    final userName = question['user_name'] as String? ?? '用户';
    final questionText = question['question'] as String? ?? '';
    final answerText = question['answer'] as String?;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(question['created_at'] as int);
    final likeCount = question['like_count'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnswered
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 问题头部
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Text(
                  userName.isNotEmpty ? userName[0] : '用',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAnswered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已回答',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 问题内容
          Text(
            questionText,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          
          // 回答内容
          if (isAnswered && answerText != null && answerText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '商家回答',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    answerText,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 底部操作栏
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: 实现点赞功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('点赞功能开发中')),
                  );
                },
                icon: Icon(
                  Icons.thumb_up_alt_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Text(
                likeCount.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isAnswered)
                TextButton.icon(
                  onPressed: () {
                    // TODO: 实现追问功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('追问功能开发中')),
                    );
                  },
                  icon: Icon(Icons.reply, size: 16),
                  label: Text('追问'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
