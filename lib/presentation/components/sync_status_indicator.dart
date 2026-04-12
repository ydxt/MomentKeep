import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/config/supabase_config.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';
import 'package:moment_keep/presentation/pages/sync_settings_page.dart';

/// 全局同步状态指示器
/// 显示在 AppBar 中，点击可打开同步设置页面
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final config = SupabaseConfig();
    final syncManager = SupabaseSyncManager();

    // 根据配置和同步状态显示不同图标
    IconData icon;
    Color? color;
    String tooltip;

    if (!config.syncEnabled) {
      icon = Icons.cloud_off;
      color = theme.colorScheme.onSurfaceVariant;
      tooltip = '同步未启用';
    } else if (!config.isConfigured) {
      icon = Icons.cloud_off;
      color = theme.colorScheme.error;
      tooltip = '同步未配置';
    } else {
      switch (config.syncStatus) {
        case 'syncing':
          icon = Icons.cloud_sync;
          color = theme.colorScheme.primary;
          tooltip = '正在同步...';
          break;
        case 'synced':
          icon = Icons.cloud_done;
          color = Colors.green;
          tooltip = '已同步';
          break;
        case 'error':
          icon = Icons.cloud_off;
          color = theme.colorScheme.error;
          tooltip = '同步错误';
          break;
        case 'offline':
          icon = Icons.cloud_off;
          color = theme.colorScheme.onSurfaceVariant;
          tooltip = '离线';
          break;
        default:
          icon = Icons.cloud_queue;
          color = theme.colorScheme.onSurfaceVariant;
          tooltip = '同步状态未知';
      }
    }

    return StreamBuilder<double>(
      stream: syncManager.progressStream,
      builder: (context, snapshot) {
        final progress = snapshot.data;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (config.syncStatus == 'syncing' && progress != null)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                  color: theme.colorScheme.primary,
                ),
              ),
            IconButton(
              icon: Icon(icon, color: color),
              tooltip: tooltip,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SyncSettingsPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// 简化的同步状态图标（无进度环）
class SimpleSyncStatusIcon extends ConsumerWidget {
  const SimpleSyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final config = SupabaseConfig();

    IconData icon;
    Color? color;

    if (!config.syncEnabled) {
      icon = Icons.cloud_off;
      color = theme.colorScheme.onSurfaceVariant;
    } else if (!config.isConfigured) {
      icon = Icons.cloud_off;
      color = theme.colorScheme.error;
    } else {
      switch (config.syncStatus) {
        case 'syncing':
          icon = Icons.cloud_sync;
          color = theme.colorScheme.primary;
          break;
        case 'synced':
          icon = Icons.cloud_done;
          color = Colors.green;
          break;
        case 'error':
          icon = Icons.cloud_off;
          color = theme.colorScheme.error;
          break;
        case 'offline':
          icon = Icons.cloud_off;
          color = theme.colorScheme.onSurfaceVariant;
          break;
        default:
          icon = Icons.cloud_queue;
          color = theme.colorScheme.onSurfaceVariant;
      }
    }

    return Icon(icon, color: color, size: 20);
  }
}

/// 同步状态文本
class SyncStatusText extends ConsumerWidget {
  const SyncStatusText({super.key, this.showTime = true});

  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final config = SupabaseConfig();

    String statusText;

    if (!config.syncEnabled) {
      statusText = '同步未启用';
    } else if (!config.isConfigured) {
      statusText = '同步未配置';
    } else {
      switch (config.syncStatus) {
        case 'syncing':
          statusText = '正在同步...';
          break;
        case 'synced':
          statusText = showTime && config.lastSyncAt != null
              ? '已同步 ${_formatTime(config.lastSyncAt!)}'
              : '已同步';
          break;
        case 'error':
          statusText = '同步错误';
          break;
        case 'offline':
          statusText = '离线';
          break;
        default:
          statusText = config.syncStatus;
      }
    }

    return Text(
      statusText,
      style: TextStyle(
        fontSize: 12,
        color: _getStatusColor(config.syncStatus, config, theme),
      ),
    );
  }

  Color _getStatusColor(String status, SupabaseConfig config, dynamic theme) {
    if (!config.syncEnabled || !config.isConfigured) {
      return theme.colorScheme.onSurfaceVariant;
    }

    switch (status) {
      case 'syncing':
        return theme.colorScheme.primary;
      case 'synced':
        return Colors.green;
      case 'error':
        return theme.colorScheme.error;
      case 'offline':
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
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
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
