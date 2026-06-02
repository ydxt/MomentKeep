import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';

class CardSecretPage extends ConsumerStatefulWidget {
  const CardSecretPage({super.key, this.orderId});

  final String? orderId;

  @override
  ConsumerState<CardSecretPage> createState() => _CardSecretPageState();
}

class _CardSecretPageState extends ConsumerState<CardSecretPage> {
  final ProductDatabaseService _dbService = ProductDatabaseService();
  final DatabaseService _userService = DatabaseService();
  List<Map<String, dynamic>> _cardSecrets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCardSecrets();
  }

  Future<void> _loadCardSecrets() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = await _userService.getCurrentUserId() ?? 'default_user';

      List<Map<String, dynamic>> secrets;
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        secrets = await _dbService.getCardSecretsByOrderId(widget.orderId!);
      } else {
        secrets = await _dbService.getCardSecretsByUserId(currentUserId);
      }

      setState(() {
        _cardSecrets = secrets;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载卡密失败: $e');
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label已复制'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'unused':
        return '未使用';
      case 'used':
        return '已使用';
      case 'expired':
        return '已过期';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'unused':
        return const Color(0xFF13ec5b);
      case 'used':
        return const Color(0xFF92c9a4);
      case 'expired':
        return const Color(0xFFff6b6b);
      default:
        return Colors.grey;
    }
  }

  Widget _buildCardSecretItem(Map<String, dynamic> secret, ThemeData theme) {
    final productName = secret['product_name'] as String? ?? '未知商品';
    final cardSecret = secret['card_secret'] as String? ?? '';
    final status = secret['status'] as String? ?? 'unused';
    final createdAt = secret['created_at'] as int?;
    final expiresAt = secret['expires_at'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
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
                    productName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cardSecret,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyToClipboard(cardSecret, '卡密'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.copy,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: theme.colorScheme.outline.withOpacity(0.1),
              thickness: 0.5,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '获取时间：${createdAt != null ? _formatDate(DateTime.fromMillisecondsSinceEpoch(createdAt)) : '未知'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '过期时间：${_formatDate(DateTime.fromMillisecondsSinceEpoch(expiresAt))}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
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
            Icons.key_off,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.orderId != null ? '该订单暂无卡密' : '暂无卡密',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '购买虚拟商品后可在此查看卡密',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.orderId != null ? '订单卡密' : '我的卡密',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : _cardSecrets.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _loadCardSecrets,
                  color: theme.colorScheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cardSecrets.length,
                    itemBuilder: (context, index) {
                      return _buildCardSecretItem(_cardSecrets[index], theme);
                    },
                  ),
                ),
    );
  }
}
