import 'package:flutter/material.dart';

/// 空状态类型枚举
enum EmptyStateType {
  habits,
  todos,
  diaries,
  pomodoros,
  search,
  completed,
  notifications,
  generic,
}

/// 统一空状态组件
class EmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customSubtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    Key? key,
    required this.type,
    this.customTitle,
    this.customSubtitle,
    this.onAction,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getConfig(type);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 插图/图标
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: config.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                config.icon,
                size: 64,
                color: config.iconColor,
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              customTitle ?? config.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 副标题
            Text(
              customSubtitle ?? config.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 操作按钮（可选）
            if (onAction != null)
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(config.actionIcon),
                label: Text(actionLabel ?? config.actionLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _EmptyStateConfig _getConfig(EmptyStateType type) {
    switch (type) {
      case EmptyStateType.habits:
        return _EmptyStateConfig(
          icon: Icons.fitness_center,
          iconColor: const Color(0xFF4CAF50),
          bgColor: const Color(0xFF4CAF50).withOpacity(0.1),
          title: '还没有习惯',
          subtitle: '创建你的第一个习惯，开始改变生活！',
          actionIcon: Icons.add,
          actionLabel: '创建习惯',
        );
      case EmptyStateType.todos:
        return _EmptyStateConfig(
          icon: Icons.checklist,
          iconColor: const Color(0xFF2196F3),
          bgColor: const Color(0xFF2196F3).withOpacity(0.1),
          title: '待办事项为空',
          subtitle: '添加新任务，高效管理你的时间',
          actionIcon: Icons.add_task,
          actionLabel: '添加待办',
        );
      case EmptyStateType.diaries:
        return _EmptyStateConfig(
          icon: Icons.menu_book,
          iconColor: const Color(0xFFFF9800),
          bgColor: const Color(0xFFFF9800).withOpacity(0.1),
          title: '还没有日记',
          subtitle: '记录生活的点点滴滴，留下美好回忆',
          actionIcon: Icons.edit,
          actionLabel: '写日记',
        );
      case EmptyStateType.search:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          iconColor: const Color(0xFF757575),
          bgColor: const Color(0xFF757575).withOpacity(0.1),
          title: '未找到结果',
          subtitle: '尝试其他关键词搜索',
          actionIcon: Icons.refresh,
          actionLabel: '清除搜索',
        );
      case EmptyStateType.completed:
        return _EmptyStateConfig(
          icon: Icons.celebration,
          iconColor: const Color(0xFFFFC107),
          bgColor: const Color(0xFFFFC107).withOpacity(0.1),
          title: '全部完成！',
          subtitle: '太棒了！你没有待处理的任务',
          actionIcon: Icons.check_circle,
          actionLabel: '查看已完成',
        );
      default:
        return _EmptyStateConfig(
          icon: Icons.inbox,
          iconColor: const Color(0xFF757575),
          bgColor: const Color(0xFF757575).withOpacity(0.1),
          title: '暂无内容',
          subtitle: '点击添加按钮创建新内容',
          actionIcon: Icons.add,
          actionLabel: '添加',
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final String actionLabel;

  _EmptyStateConfig({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    required this.actionLabel,
  });
}
