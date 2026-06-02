import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/components/responsive_navigation.dart';
import 'package:moment_keep/presentation/pages/home_page.dart';
import 'package:moment_keep/presentation/pages/dashboard_page.dart';
import 'package:moment_keep/presentation/pages/diary_page.dart';
import 'package:moment_keep/presentation/pages/habit_page.dart';
import 'package:moment_keep/presentation/pages/todo_page.dart';
import 'package:moment_keep/presentation/pages/star_exchange_page.dart';
import 'package:moment_keep/presentation/pages/bills_page.dart';
import 'package:moment_keep/presentation/pages/my_orders_page.dart';
import 'package:moment_keep/presentation/pages/merchant_order_management_page.dart';
import 'package:moment_keep/presentation/pages/merchant_product_management_page.dart';
import 'package:moment_keep/presentation/pages/add_product_step_by_step_page.dart';
import 'package:moment_keep/presentation/pages/product_review_page.dart';
import 'package:moment_keep/presentation/pages/order_detail_page.dart';

/// 页面遍历测试，用于检查所有页面的主题是否正确应用
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('页面主题遍历测试', () {
    // 测试的页面列表 - 包括我们修复过的所有页面
    final List<Widget> pagesToTest = [
      const StarExchangePage(),
      const BillsPage(),
      const MyOrdersPage(),
      const MerchantOrderManagementPage(),
      const MerchantProductManagementPage(),
      AddProductStepByStepPage(onSubmit: () async {}),
      const ProductReviewPage(),
    ];
    
    // 页面名称映射
    final Map<Type, String> pageNames = {
      StarExchangePage: '星星兑换页面',
      BillsPage: '账单页面',
      MyOrdersPage: '客户我的订单页面',
      MerchantOrderManagementPage: '商家订单管理页面',
      MerchantProductManagementPage: '商家商品管理页面',
      AddProductStepByStepPage: '新增商品页面',
      ProductReviewPage: '商品审核页面',
    };
    
    // 测试每个页面在不同主题下的显示
    for (final page in pagesToTest) {
      final pageName = pageNames[page.runtimeType] ?? page.runtimeType.toString();
      
      testWidgets('$pageName - 主题切换测试', (WidgetTester tester) async {
        await _testPageTheme(tester, page, pageName);
      });
    }
  });
  
  group('主题组件测试', () {
    // 测试各种UI组件在主题切换时的表现
    testWidgets('主题组件综合测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final theme = ref.watch(currentThemeProvider);
                  return Container(
                    color: theme.colorScheme.background,
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // 测试各种文本样式
                          Text('Headline 1', style: theme.textTheme.headlineLarge),
                          Text('Body Text', style: theme.textTheme.bodyMedium),
                          Text('Caption', style: theme.textTheme.bodySmall),
                          
                          const SizedBox(height: 20),
                          
                          // 测试按钮
                          ElevatedButton(
                            onPressed: () {},
                            child: Text('Elevated Button'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {},
                            child: Text('Text Button'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () {},
                            child: Text('Outlined Button'),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 测试卡片
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Test Card', style: theme.textTheme.bodyMedium),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 测试输入框
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Test Input',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 测试开关和复选框
                          Switch(value: true, onChanged: (_) {}),
                          const SizedBox(height: 10),
                          Checkbox(value: true, onChanged: (_) {}),
                          const SizedBox(height: 10),
                          Radio(value: true, groupValue: true, onChanged: (_) {}),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      
      // 切换主题
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 500));
      
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
      await tester.pump(const Duration(milliseconds: 500));
      
      print('✓ 主题组件综合测试通过');
    });
  });
}

/// 测试页面在不同主题下的显示
Future<void> _testPageTheme(WidgetTester tester, Widget page, String pageName) async {
  // 构建测试应用
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: page,
      ),
    ),
  );
  
  // 等待页面渲染
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  // 获取容器
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  
  // 测试1: 初始主题应为浅色
  var theme = container.read(currentThemeProvider);
  expect(theme.brightness, Brightness.light, reason: '$pageName - 初始主题不是浅色');
  print('✓ $pageName - 初始主题为浅色');
  
  // 测试2: 检查页面是否有明显的硬编码黑色背景
  _checkForHardcodedDarkBackgrounds(tester, pageName);
  
  // 测试3: 切换到深色主题
  container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  theme = container.read(currentThemeProvider);
  expect(theme.brightness, Brightness.dark, reason: '$pageName - 无法切换到深色主题');
  print('✓ $pageName - 成功切换到深色主题');
  
  // 测试4: 检查深色主题下是否正常显示
  _checkForHardcodedLightBackgrounds(tester, pageName);
  
  // 测试5: 切换回浅色主题
  container.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  theme = container.read(currentThemeProvider);
  expect(theme.brightness, Brightness.light, reason: '$pageName - 无法切换回浅色主题');
  print('✓ $pageName - 成功切换回浅色主题');
  
  print('✅ $pageName - 主题测试通过');
}

/// 检查页面是否有明显的硬编码黑色背景
void _checkForHardcodedDarkBackgrounds(WidgetTester tester, String pageName) {
  // 查找所有Container组件
  final containers = find.byType(Container);
  
  for (final element in containers.evaluate()) {
    final container = element.widget as Container;
    
    // 检查容器的背景色
    if (container.decoration is BoxDecoration) {
      final decoration = container.decoration as BoxDecoration;
      if (decoration.color == Colors.black) {
        fail('$pageName - 发现硬编码的黑色背景');
      }
      if (decoration.color == const Color(0xFF1a3525)) {
        fail('$pageName - 发现硬编码的深绿色背景');
      }
      if (decoration.color == const Color(0xFF2a4532)) {
        fail('$pageName - 发现硬编码的深绿色背景');
      }
    }
    
    // 检查容器的颜色属性
    if (container.color == Colors.black) {
      fail('$pageName - 发现硬编码的黑色背景');
    }
    if (container.color == const Color(0xFF1a3525)) {
      fail('$pageName - 发现硬编码的深绿色背景');
    }
    if (container.color == const Color(0xFF2a4532)) {
      fail('$pageName - 发现硬编码的深绿色背景');
    }
  }
  
  print('✓ $pageName - 没有发现硬编码的深色背景');
}

/// 检查页面是否有明显的硬编码浅色背景（在深色主题下不适合）
void _checkForHardcodedLightBackgrounds(WidgetTester tester, String pageName) {
  // 查找所有Container组件
  final containers = find.byType(Container);
  
  for (final element in containers.evaluate()) {
    final container = element.widget as Container;
    
    // 检查容器的背景色
    if (container.decoration is BoxDecoration) {
      final decoration = container.decoration as BoxDecoration;
      if (decoration.color == Colors.white) {
        fail('$pageName - 深色主题下发现硬编码的白色背景');
      }
    }
    
    // 检查容器的颜色属性
    if (container.color == Colors.white) {
      fail('$pageName - 深色主题下发现硬编码的白色背景');
    }
  }
  
  print('✓ $pageName - 深色主题下没有发现硬编码的浅色背景');
}
