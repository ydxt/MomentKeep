import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class MembershipTier {
  final String name;
  final String icon;
  final Color color;
  final int minPoints;
  final List<String> benefits;

  const MembershipTier({
    required this.name,
    required this.icon,
    required this.color,
    required this.minPoints,
    required this.benefits,
  });
}

class MembershipBenefitsPage extends ConsumerStatefulWidget {
  final String userId;
  final int userPoints;
  final String currentLevel;

  const MembershipBenefitsPage({
    super.key,
    required this.userId,
    this.userPoints = 0,
    this.currentLevel = '青铜会员',
  });

  @override
  ConsumerState<MembershipBenefitsPage> createState() =>
      _MembershipBenefitsPageState();
}

class _MembershipBenefitsPageState extends ConsumerState<MembershipBenefitsPage> {
  final tiers = const [
    MembershipTier(
      name: '青铜会员',
      icon: '⭐',
      color: Color(0xFFcd7f32),
      minPoints: 0,
      benefits: ['专属客服', '生日礼包'],
    ),
    MembershipTier(
      name: '白银会员',
      icon: '⭐⭐',
      color: Color(0xFFc0c0c0),
      minPoints: 1000,
      benefits: ['青铜权益', '运费折扣', '优先发货'],
    ),
    MembershipTier(
      name: '黄金会员',
      icon: '⭐⭐⭐',
      color: Color(0xFFffd700),
      minPoints: 5000,
      benefits: ['白银权益', '专属折扣', '积分加速'],
    ),
    MembershipTier(
      name: '钻石会员',
      icon: '💎',
      color: Color(0xFFb9f2ff),
      minPoints: 10000,
      benefits: ['黄金权益', '专属客服', '限量商品'],
    ),
  ];

  int _getCurrentTierIndex() {
    int index = 0;
    for (int i = tiers.length - 1; i >= 0; i--) {
      if (widget.userPoints >= tiers[i].minPoints) {
        index = i;
        break;
      }
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final currentTierIndex = _getCurrentTierIndex();
    final currentTier = tiers[currentTierIndex];
    final nextTier = currentTierIndex < tiers.length - 1 ? tiers[currentTierIndex + 1] : null;
    final progress = nextTier != null
        ? (widget.userPoints - currentTier.minPoints) / (nextTier.minPoints - currentTier.minPoints)
        : 1.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        title: Text(
          '会员权益',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentLevelCard(currentTier, nextTier, progress, theme),
            const SizedBox(height: 24),
            Text(
              '会员等级一览',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...tiers.asMap().entries.map((entry) {
              final index = entry.key;
              final tier = entry.value;
              final isCurrent = index == currentTierIndex;
              final isUnlocked = widget.userPoints >= tier.minPoints;
              return _buildTierCard(tier, isCurrent, isUnlocked, theme);
            }),
            const SizedBox(height: 24),
            Text(
              '我的权益清单',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildBenefitsChecklist(currentTier, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLevelCard(
    MembershipTier tier,
    MembershipTier? nextTier,
    double progress,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            tier.color.withOpacity(0.3),
            tier.color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: tier.color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier.icon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: tier.color,
                      ),
                    ),
                    Text(
                      '当前积分: ✨${widget.userPoints}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 20),
            Text(
              '距离 ${nextTier.name} 还差 ${nextTier.minPoints - widget.userPoints} 积分',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(tier.color),
                minHeight: 8,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '🎉 恭喜！您已达到最高会员等级！',
              style: TextStyle(
                fontSize: 14,
                color: tier.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierCard(
    MembershipTier tier,
    bool isCurrent,
    bool isUnlocked,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant,
        border: Border.all(
          color: isCurrent
              ? tier.color.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier.icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                tier.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? tier.color : theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isUnlocked ? Colors.green.withOpacity(0.2) : theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
                ),
                child: Text(
                  isUnlocked ? '✨${tier.minPoints} 已达成' : '需要 ✨${tier.minPoints}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? Colors.green : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tier.benefits.map((benefit) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: tier.color.withOpacity(0.1),
                ),
                child: Text(
                  benefit,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? tier.color : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsChecklist(MembershipTier tier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        children: tier.benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: tier.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  benefit,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
