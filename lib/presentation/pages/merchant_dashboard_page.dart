import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:moment_keep/presentation/pages/merchant_product_management_page.dart';
import 'package:moment_keep/presentation/pages/merchant_finance_page.dart';
import 'package:moment_keep/presentation/pages/merchant_payment_records_page.dart';
import 'package:moment_keep/presentation/pages/merchant_message_center_page.dart';
import 'package:moment_keep/presentation/pages/product_review_management_page.dart';

class MerchantDashboardPage extends ConsumerWidget {
  const MerchantDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    
    final features = [
      {'icon': Icons.receipt_long, 'label': '订单管理', 'page': MerchantOrderManagementPage()},
      {'icon': Icons.inventory, 'label': '商品管理', 'page': const MerchantProductManagementPage()},
      {'icon': Icons.bar_chart, 'label': '财务统计', 'page': const MerchantFinancePage()},
      {'icon': Icons.payment, 'label': '支付记录', 'page': const MerchantPaymentRecordsPage()},
      {'icon': Icons.message, 'label': '消息中心', 'page': const MerchantMessageCenterPage()},
      {'icon': Icons.star, 'label': '评价管理', 'page': const ProductReviewManagementPage()},
    ];
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('商家中心'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '商家服务',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return _buildFeatureItem(
                    icon: feature['icon'] as IconData,
                    label: feature['label'] as String,
                    page: feature['page'] as Widget,
                    theme: theme,
                    context: context,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required Widget page,
    required ThemeData theme,
    required BuildContext context,
  }) {
    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
