import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/presentation/blocs/achievement_bloc.dart';
import 'package:moment_keep/domain/entities/achievement.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 成就页面
class AchievementPage extends StatelessWidget {
  /// 构造函数
  const AchievementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AchievementBloc()..add(LoadAchievements()),
      child: const AchievementView(),
    );
  }
}

/// 成就视图
class AchievementView extends ConsumerWidget {
  /// 构造函数
  const AchievementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('成就系统'),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: BlocBuilder<AchievementBloc, AchievementState>(
        builder: (context, state) {
          if (state is AchievementLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AchievementError) {
            return Center(child: Text(state.message));
          } else if (state is AchievementLoaded) {
            return AchievementContent(achievements: state.achievements);
          }
          return const Center(child: Text('暂无成就'));
        },
      ),
    );
  }
}

/// 成就内容组件
class AchievementContent extends StatelessWidget {
  /// 成就列表
  final List<Achievement> achievements;

  /// 构造函数
  const AchievementContent({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    // 按类型分组成就
    final groupedAchievements = <AchievementType, List<Achievement>>{};
    for (final achievement in achievements) {
      if (!groupedAchievements.containsKey(achievement.type)) {
        groupedAchievements[achievement.type] = [];
      }
      groupedAchievements[achievement.type]!.add(achievement);
    }

    // 计算解锁率
    final totalAchievements = achievements.length;
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).length;
    final unlockRate =
        totalAchievements > 0 ? unlockedAchievements / totalAchievements : 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 解锁率统计
          AchievementStatsCard(
            totalAchievements: totalAchievements,
            unlockedAchievements: unlockedAchievements,
            unlockRate: unlockRate.toDouble(),
          )
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 500))
              .slideY(begin: -20, duration: const Duration(milliseconds: 500)),

          // 成就列表，按类型分组
          for (final type in AchievementType.values)
            if (groupedAchievements.containsKey(type))
              AchievementSection(
                type: type,
                achievements: groupedAchievements[type]!,
              )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(
                      begin: 20, duration: const Duration(milliseconds: 500)),
        ],
      ),
    );
  }
}

/// 成就统计卡片
class AchievementStatsCard extends ConsumerWidget {
  /// 总成就数
  final int totalAchievements;

  /// 已解锁成就数
  final int unlockedAchievements;

  /// 解锁率
  final double unlockRate;

  /// 构造函数
  const AchievementStatsCard({
    super.key,
    required this.totalAchievements,
    required this.unlockedAchievements,
    required this.unlockRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '成就统计',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // 环形进度图
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: unlockRate,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary),
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(unlockRate * 100).toInt()}%',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$unlockedAchievements/$totalAchievements',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 解锁成就数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  label: '总成就',
                  value: totalAchievements.toString(),
                  theme: theme,
                ),
                _buildStatItem(
                  label: '已解锁',
                  value: unlockedAchievements.toString(),
                  theme: theme,
                ),
                _buildStatItem(
                  label: '未解锁',
                  value: (totalAchievements - unlockedAchievements).toString(),
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem({required String label, required String value, required ThemeData theme}) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 成就分类标题
class AchievementSection extends ConsumerWidget {
  /// 成就类型
  final AchievementType type;

  /// 成就列表
  final List<Achievement> achievements;

  /// 构造函数
  const AchievementSection(
      {super.key, required this.type, required this.achievements});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标题
          Text(
            _getTypeName(type),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          // 成就列表
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return AchievementItem(achievement: achievement)
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 300))
                  .slideY(
                      begin: 20, duration: const Duration(milliseconds: 300));
            },
          ),
        ],
      ),
    );
  }

  /// 获取类型名称
  String _getTypeName(AchievementType type) {
    switch (type) {
      case AchievementType.habit:
        return '习惯成就';
      case AchievementType.plan:
        return '计划成就';
      case AchievementType.pomodoro:
        return '专注成就';
      case AchievementType.todo:
        return '任务成就';
      case AchievementType.diary:
        return '日记成就';
    }
  }
}

/// 成就项组件
class AchievementItem extends ConsumerWidget {
  /// 成就
  final Achievement achievement;

  /// 构造函数
  const AchievementItem({super.key, required this.achievement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: achievement.isUnlocked
              ? theme.colorScheme.secondary
              : theme.colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      elevation: 2,
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成就图标和状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  _getAchievementIcon(achievement.type),
                  size: 32,
                  color: achievement.isUnlocked
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline,
                ),
                Icon(
                  achievement.isUnlocked ? Icons.lock_open : Icons.lock,
                  color: achievement.isUnlocked
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 成就名称
            Text(
              achievement.name,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 成就描述
            Text(
              achievement.description,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 进度条
            LinearProgressIndicator(
              value: achievement.requiredProgress > 0
                  ? achievement.currentProgress / achievement.requiredProgress
                  : 1.0,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(achievement.isUnlocked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary),
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 4),
            // 进度文字
            Text(
              '${achievement.currentProgress}/${achievement.requiredProgress}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
            // 解锁时间
            if (achievement.isUnlocked && achievement.unlockedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '解锁于: ${_formatDate(achievement.unlockedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 获取成就图标
  IconData _getAchievementIcon(AchievementType type) {
    switch (type) {
      case AchievementType.habit:
        return Icons.track_changes;
      case AchievementType.plan:
        return Icons.event_note;
      case AchievementType.pomodoro:
        return Icons.access_alarm;
      case AchievementType.todo:
        return Icons.checklist;
      case AchievementType.diary:
        return Icons.book;
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}
