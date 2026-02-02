import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 弹窗和对话框主题测试
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('弹窗和对话框主题测试', () {
    testWidgets('AlertDialog 主题测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final theme = Theme.of(context);
                        return AlertDialog(
                          title: Text('测试对话框', style: theme.textTheme.titleLarge),
                          content: Text('这是一个测试对话框，用于测试主题应用情况', style: theme.textTheme.bodyMedium),
                          backgroundColor: theme.colorScheme.surface,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('取消', style: TextStyle(color: theme.colorScheme.primary)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('确定'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('打开对话框'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 打开对话框
      await tester.tap(find.text('打开对话框'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证对话框是否显示
      expect(find.text('测试对话框'), findsOneWidget);
      
      // 获取容器
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      
      // 切换到深色主题
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 关闭对话框
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      print('✓ AlertDialog 主题测试通过');
    });
    
    testWidgets('SimpleDialog 主题测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final theme = Theme.of(context);
                        return SimpleDialog(
                          title: Text('选择选项', style: theme.textTheme.titleLarge),
                          backgroundColor: theme.colorScheme.surface,
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, '选项1'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('选项1', style: theme.textTheme.bodyMedium),
                              ),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, '选项2'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('选项2', style: theme.textTheme.bodyMedium),
                              ),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, '选项3'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('选项3', style: theme.textTheme.bodyMedium),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('打开选择对话框'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 打开对话框
      await tester.tap(find.text('打开选择对话框'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证对话框是否显示
      expect(find.text('选择选项'), findsOneWidget);
      
      // 获取容器
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      
      // 切换到深色主题
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 关闭对话框
      await tester.tap(find.text('选项1'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      print('✓ SimpleDialog 主题测试通过');
    });
    
    testWidgets('BottomSheet 主题测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        final theme = Theme.of(context);
                        return Container(
                          color: theme.colorScheme.surface,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('底部弹出菜单', style: theme.textTheme.titleLarge),
                              const SizedBox(height: 16),
                              ListTile(
                                title: Text('选项1', style: theme.textTheme.bodyMedium),
                                onTap: () => Navigator.pop(context),
                              ),
                              ListTile(
                                title: Text('选项2', style: theme.textTheme.bodyMedium),
                                onTap: () => Navigator.pop(context),
                              ),
                              ListTile(
                                title: Text('选项3', style: theme.textTheme.bodyMedium),
                                onTap: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('打开底部弹出菜单'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 打开底部弹出菜单
      await tester.tap(find.text('打开底部弹出菜单'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证底部弹出菜单是否显示
      expect(find.text('底部弹出菜单'), findsOneWidget);
      
      // 获取容器
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      
      // 切换到深色主题
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 关闭底部弹出菜单
      await tester.tap(find.text('选项1'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      print('✓ BottomSheet 主题测试通过');
    });
    
    testWidgets('SnackBar 主题测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    final theme = Theme.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('这是一个测试SnackBar', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        backgroundColor: theme.colorScheme.primary,
                        action: SnackBarAction(
                          label: '撤销',
                          onPressed: () {},
                          textColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    );
                  },
                  child: const Text('显示SnackBar'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 显示SnackBar
      await tester.tap(find.text('显示SnackBar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证SnackBar是否显示
      expect(find.text('这是一个测试SnackBar'), findsOneWidget);
      
      print('✓ SnackBar 主题测试通过');
    });
    
    testWidgets('自定义对话框主题测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final theme = Theme.of(context);
                        return Dialog(
                          backgroundColor: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text('自定义对话框', style: theme.textTheme.titleLarge),
                                const SizedBox(height: 8),
                                Text('这是一个自定义对话框，用于测试主题应用情况', style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('确定'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('打开自定义对话框'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 打开自定义对话框
      await tester.tap(find.text('打开自定义对话框'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证自定义对话框是否显示
      expect(find.text('自定义对话框'), findsOneWidget);
      
      // 获取容器
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      
      // 切换到深色主题
      container.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 关闭自定义对话框
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      print('✓ 自定义对话框主题测试通过');
    });
  });
  
  group('主题切换时的弹窗测试', () {
    testWidgets('对话框主题响应性测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final theme = ref.watch(currentThemeProvider);
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final dialogTheme = Theme.of(context);
                          return AlertDialog(
                            title: Text('测试对话框', style: dialogTheme.textTheme.titleLarge),
                            content: Text('当前主题亮度: ${dialogTheme.brightness}', style: dialogTheme.textTheme.bodyMedium),
                            backgroundColor: dialogTheme.colorScheme.surface,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('关闭', style: TextStyle(color: dialogTheme.colorScheme.primary)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text('当前主题: ${theme.brightness}', style: theme.textTheme.bodyLarge),
                  );
                },
              ),
            ),
          ),
        ),
      );
      
      await tester.pump(const Duration(milliseconds: 500));
      
      // 验证初始主题是浅色
      expect(find.text('当前主题: Brightness.light'), findsOneWidget);
      
      // 打开对话框
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // 验证对话框显示
      expect(find.text('测试对话框'), findsOneWidget);
      
      // 关闭对话框
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      print('✓ 对话框主题响应性测试通过');
    });
  });
}