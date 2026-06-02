import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/presentation/pages/invoice_management_page.dart';
import 'package:moment_keep/presentation/pages/real_name_auth_page.dart';
import 'package:moment_keep/presentation/pages/membership_benefits_page.dart';
import 'package:moment_keep/presentation/pages/settings_page.dart';

class MoreFeaturesPage extends ConsumerWidget {
  const MoreFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('更多功能'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: FutureBuilder<String?>(
        future: DatabaseService().getCurrentUserId(),
        builder: (context, snapshot) {
          final userId = snapshot.data ?? 'default_user';

          final features = [
            {
              'icon': Icons.receipt_long,
              'label': '发票管理',
              'description': '申请和管理发票',
              'builder': () => InvoiceManagementPage(userId: userId),
            },
            {
              'icon': Icons.verified_user,
              'label': '实名认证',
              'description': '完成身份认证',
              'builder': () => const RealNameAuthPage(),
            },
            {
              'icon': Icons.workspace_premium,
              'label': '会员权益',
              'description': '查看会员特权',
              'builder': () => MembershipBenefitsPage(userId: userId),
            },
            {
              'icon': Icons.settings,
              'label': '系统设置',
              'description': '个性化配置',
              'builder': () => const SettingsPage(),
            },
            {
              'icon': Icons.help_outline,
              'label': '帮助中心',
              'description': '常见问题解答',
              'builder': () => const HelpCenterPage(),
            },
            {
              'icon': Icons.feedback_outlined,
              'label': '意见反馈',
              'description': '提交使用建议',
              'builder': () => const FeedbackPage(),
            },
            {
              'icon': Icons.security,
              'label': '隐私政策',
              'description': '隐私保护条款',
              'builder': () => const PrivacyPolicyPage(),
            },
            {
              'icon': Icons.info_outline,
              'label': '关于我们',
              'description': '应用版本信息',
              'builder': () => const AboutUsPage(),
            },
          ];

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: features.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureItem(
                icon: feature['icon'] as IconData,
                label: feature['label'] as String,
                description: feature['description'] as String,
                builder: feature['builder'] as Widget Function()?,
                theme: theme,
                context: context,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String description,
    required Widget Function()? builder,
    required ThemeData theme,
    required BuildContext context,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(label),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: builder != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => builder()),
              );
            }
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label 功能开发中')),
              );
            },
    );
  }
}

class HelpCenterPage extends ConsumerWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final faqs = [
      {'q': '如何赚取积分？', 'a': '完成待办事项、坚持习惯打卡、写日记等日常操作均可获得积分奖励。不同行为对应不同积分，详见积分统计页面。'},
      {'q': '积分有什么用途？', 'a': '积分可在星星商店中兑换实物商品和虚拟商品，也可用于抵扣订单金额。'},
      {'q': '如何申请退款？', 'a': '在"我的订单"中选择需要退款的订单，点击"申请售后"，选择退款原因并提交。虚拟商品未激活状态下可退款。'},
      {'q': '虚拟商品如何使用？', 'a': '购买虚拟商品后，系统会自动发放卡密或开通权益。您可在"卡密中心"查看已购卡密，复制后按说明使用。'},
      {'q': '如何修改收货地址？', 'a': '进入"个人中心"→"收货地址管理"，可新增、编辑或删除地址，也可设置默认地址。'},
      {'q': '会员等级如何提升？', 'a': '通过消费累计成长值，成长值达到对应阈值后自动升级。不同等级享受不同折扣和专属权益。'},
      {'q': '如何联系客服？', 'a': '在星星商店中点击"客服中心"，可通过智能客服获取常见问题解答，也可转接人工客服。'},
      {'q': '数据会丢失吗？', 'a': '所有数据存储在本地数据库中，建议定期备份。如需跨设备同步，请关注后续云端同步功能。'},
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('帮助中心', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(faq['q']!, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
              children: [
                Text(faq['a']!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.6)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _contentController = TextEditingController();
  String _selectedCategory = '功能建议';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final categories = ['功能建议', '问题反馈', '体验优化', '其他'];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('意见反馈', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('反馈类型', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('反馈内容', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '请详细描述您的建议或遇到的问题...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_contentController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('请输入反馈内容')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('感谢您的反馈，我们会认真处理！'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('提交反馈'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends ConsumerWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final sections = [
      {'title': '信息收集', 'content': '我们仅收集您主动提供的信息，包括：账户信息（用户名、手机号）、交易信息（订单、支付记录）、设备信息（用于适配和优化体验）。我们不会在未经您同意的情况下收集任何额外信息。'},
      {'title': '信息使用', 'content': '您的信息仅用于：提供和改善服务功能、处理订单和售后、发送交易通知和安全提醒、个性化推荐。我们绝不会将您的信息出售给第三方。'},
      {'title': '信息存储', 'content': '所有数据存储在您的本地设备中，采用加密存储技术保障安全。云端同步功能（如启用）将使用加密传输协议保护数据安全。'},
      {'title': '信息共享', 'content': '除以下情况外，我们不会共享您的信息：获得您的明确授权、法律法规要求、保护用户及公众的安全。商家仅能看到订单所需的配送信息。'},
      {'title': '您的权利', 'content': '您有权：查看和修改个人信息、删除账户及关联数据、撤回授权同意、获取个人数据副本。如需行使以上权利，请通过意见反馈联系我们。'},
      {'title': '安全措施', 'content': '我们采取以下措施保护您的信息：数据加密存储、安全传输协议（HTTPS）、支付信息脱敏处理、定期安全审计、访问权限严格控制。'},
      {'title': '未成年人保护', 'content': '我们高度重视未成年人信息保护。若您是未成年人，请在监护人指导下使用本应用。我们不会主动收集未成年人敏感信息。'},
      {'title': '政策更新', 'content': '本隐私政策可能会不时更新。重大变更将通过应用内通知或弹窗方式告知您。继续使用本应用即表示您同意更新后的隐私政策。'},
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('隐私政策', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${index + 1}. ${section['title']!}',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section['content']!,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.7),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AboutUsPage extends ConsumerWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('关于我们', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_stories, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('拾光记', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('MomentKeep', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('v1.0.0', style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关于拾光记', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    '拾光记是一款集待办管理、习惯养成、日记记录、番茄钟和数据统计于一体的个人成长应用。通过积分体系和星星商店，让每一天的进步都有迹可循、有奖可领。',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('应用名称', '拾光记', theme),
                  _buildInfoRow('应用版本', '1.0.0', theme),
                  _buildInfoRow('技术框架', 'Flutter', theme),
                  _buildInfoRow('数据存储', '本地 SQLite', theme),
                  _buildInfoRow('支持平台', 'Android / iOS / Web / 桌面', theme),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('核心功能', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      '待办管理', '习惯养成', '日记记录', '番茄钟', '数据统计',
                      '积分体系', '星星商店', '多端适配', '深色模式',
                    ].map((feature) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(feature, style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('© 2026 拾光记团队', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
          Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
