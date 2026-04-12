import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 数据冲突解决对话框
/// 当本地和服务器数据发生冲突时，让用户选择保留哪个版本
class ConflictResolutionDialog {
  /// 显示冲突解决对话框
  /// 返回用户的选择：'local' 或 'remote'
  static Future<String?> show({
    required BuildContext context,
    required String title,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _ConflictDialogContent(
        title: title,
        localData: localData,
        remoteData: remoteData,
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      ),
    );
  }
}

class _ConflictDialogContent extends ConsumerWidget {
  final String title;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;

  const _ConflictDialogContent({
    required this.title,
    required this.localData,
    required this.remoteData,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text('数据冲突'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「$title」在本地和云端都有修改，请选择保留哪个版本：',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // 本地版本
            _buildVersionCard(
              context,
              theme,
              '本地版本',
              localData,
              localUpdatedAt,
              Icons.phone_android,
              theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),

            // VS 图标
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 云端版本
            _buildVersionCard(
              context,
              theme,
              '云端版本',
              remoteData,
              remoteUpdatedAt,
              Icons.cloud,
              theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),

            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '选择的版本将覆盖另一个版本，此操作不可恢复',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'local'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: const Text('保留本地'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'remote'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
          ),
          child: const Text('保留云端'),
        ),
      ],
    );
  }

  Widget _buildVersionCard(
    BuildContext context,
    dynamic theme,
    String label,
    Map<String, dynamic> data,
    DateTime updatedAt,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '更新于 ${_formatTime(updatedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDataPreview(data),
        ],
      ),
    );
  }

  Widget _buildDataPreview(Map<String, dynamic> data) {
    // 提取关键信息用于预览
    final title = data['title'] ?? data['name'] ?? '无标题';
    final content = data['content']?.toString() ?? '';
    final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// 冲突解决策略选择器
class ConflictStrategySelector extends ConsumerWidget {
  final Function(String strategy) onStrategyChanged;

  const ConflictStrategySelector({
    super.key,
    required this.onStrategyChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '默认冲突解决策略',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildStrategyOption(
            theme,
            'remote_wins',
            '云端优先（推荐）',
            '当发生冲突时，以云端数据为准',
            Icons.cloud,
          ),
          _buildStrategyOption(
            theme,
            'local_wins',
            '本地优先',
            '当发生冲突时，以本地数据为准',
            Icons.phone_android,
          ),
          _buildStrategyOption(
            theme,
            'last_write_wins',
            '最后写入',
            '比较更新时间，使用最新的数据',
            Icons.schedule,
          ),
          _buildStrategyOption(
            theme,
            'manual',
            '手动解决',
            '发生冲突时弹出对话框让用户选择',
            Icons.handyman,
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyOption(
    dynamic theme,
    String value,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Radio<String>(
            value: value,
            groupValue: 'last_write_wins', // TODO: 从配置中读取
            onChanged: (val) => onStrategyChanged(val ?? 'last_write_wins'),
          ),
        ],
      ),
    );
  }
}

/// 冲突解决管理器
class ConflictManager {
  final BuildContext context;

  ConflictManager(this.context);

  /// 解决单个数据冲突
  Future<String?> resolveConflict({
    required String title,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    String? strategy,
  }) async {
    // 根据策略自动解决或显示对话框
    strategy ??= 'last_write_wins'; // 默认策略

    switch (strategy) {
      case 'remote_wins':
        return 'remote';
      case 'local_wins':
        return 'local';
      case 'last_write_wins':
        return localUpdatedAt.isAfter(remoteUpdatedAt) ? 'local' : 'remote';
      case 'manual':
        return await ConflictResolutionDialog.show(
          context: context,
          title: title,
          localData: localData,
          remoteData: remoteData,
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
        );
      default:
        return 'last_write_wins';
    }
  }

  /// 批量解决冲突
  Future<Map<String, String>> resolveBatchConflicts(
    List<Map<String, dynamic>> conflicts,
  ) async {
    final results = <String, String>{};

    for (final conflict in conflicts) {
      final id = conflict['id'] as String;
      final title = conflict['title'] as String;
      final localData = conflict['local'] as Map<String, dynamic>;
      final remoteData = conflict['remote'] as Map<String, dynamic>;
      final localUpdatedAt = DateTime.parse(conflict['local_updated_at']);
      final remoteUpdatedAt = DateTime.parse(conflict['remote_updated_at']);

      final choice = await resolveConflict(
        title: title,
        localData: localData,
        remoteData: remoteData,
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      );

      if (choice != null && choice != 'cancel') {
        results[id] = choice;
      }
    }

    return results;
  }
}
