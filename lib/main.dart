import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/utils/theme_manager.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/pomodoro_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_reminder_bloc.dart';

import 'package:moment_keep/presentation/blocs/dashboard_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/presentation/blocs/achievement_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/presentation/components/responsive_navigation.dart';
import 'package:moment_keep/presentation/pages/login_page.dart';
import 'package:moment_keep/presentation/pages/register_page.dart';
import 'package:moment_keep/presentation/pages/forgot_password_page.dart';


import 'package:window_manager/window_manager.dart';

import 'package:moment_keep/core/services/auto_cleanup_service.dart';

// Route observer for tracking navigation events
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  // 确保Flutter初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    // 设置窗口标题
    await windowManager.setTitle('拾光记 - MomentKeep');
  }

  // 初始化数据库服务，确保EncryptionHelper被正确初始化
  final databaseService = DatabaseService();
  await databaseService.initialize();

  // 初始化主题管理器
  await ThemeManager.instance.initialize();

  // 执行自动清理，清理过期商品及其媒体文件
  final autoCleanupService = AutoCleanupService();
  // 初始化自动清理服务
  await autoCleanupService.initialize();
  // 使用Future.delayed确保清理操作不会阻塞应用启动
  Future.delayed(Duration.zero, () async {
    await autoCleanupService.cleanupExpiredProducts();
    // 启动后台清理任务调度
    autoCleanupService.startBackgroundCleanup();
  });

  // Windows平台相机支持已通过直接使用camera插件实现
  // 在minimal_journal_editor.dart中已添加平台特定处理

  // 为test@h.com账户充值10000积分并添加测试数据（仅首次启动时执行）
  Future.delayed(Duration.zero, () async {
    final prefs = await SharedPreferences.getInstance();
    final hasRecharged = prefs.getBool('test_account_recharged') ?? false;
    final hasAddedTestData = prefs.getBool('test_data_added') ?? false;
    
    if (!hasRecharged) {
      try {
        final databaseService = DatabaseService();
        await databaseService.rechargePointsByEmail('test@h.com', 10000);
        await prefs.setBool('test_account_recharged', true);
        debugPrint('为test@h.com账户充值10000积分成功');
      } catch (e) {
        debugPrint('为test@h.com账户充值积分失败: $e');
      }
    }
    
    // 添加测试数据：优惠券、红包和购物卡
    if (!hasAddedTestData) {
      try {
        final databaseService = DatabaseService();
        final userDatabaseService = UserDatabaseService();
        final user = await userDatabaseService.getUserByEmail('test@h.com');
        
        if (user != null) {
          final userId = user['user_id'];
          final now = DateTime.now().millisecondsSinceEpoch;
          const validityDate = '2026-01-31';
          final db = await databaseService.database;
          
          // 1. 插入500元红包
          await db.insert('red_packets', {
            'id': 'test_cash_red_packet_500',
            'user_id': userId,
            'name': '500元红包',
            'amount': 500,
            'validity': validityDate,
            'status': '可用',
            'type': '现金红包',
            'created_at': now,
            'updated_at': now,
          });
          
          // 2. 插入500星星红包（积分红包）
          await db.insert('red_packets', {
            'id': 'test_points_red_packet_500',
            'user_id': userId,
            'name': '500星星红包',
            'amount': 500,
            'validity': validityDate,
            'status': '可用',
            'type': '积分红包',
            'created_at': now,
            'updated_at': now,
          });
          
          // 3. 插入全场9折优惠券
          await db.insert('coupons', {
            'id': 'test_discount_coupon_90',
            'user_id': userId,
            'name': '全场9折优惠券',
            'amount': 0,
            'condition': 0,
            'validity': validityDate,
            'status': '可用',
            'type': '折扣券',
            'discount': 0.9,
            'created_at': now,
            'updated_at': now,
          });
          
          // 4. 插入500元购物卡
          await db.insert('shopping_cards', {
            'id': 'test_cash_card_500',
            'user_id': userId,
            'name': '500元购物卡',
            'amount': 500,
            'validity': validityDate,
            'status': '可用',
            'type': '电子卡',
            'created_at': now,
            'updated_at': now,
          });
          
          // 5. 插入500星星购物卡（积分购物卡）
          await db.insert('shopping_cards', {
            'id': 'test_points_card_500',
            'user_id': userId,
            'name': '500星星购物卡',
            'amount': 500,
            'validity': validityDate,
            'status': '可用',
            'type': '积分卡',
            'created_at': now,
            'updated_at': now,
          });
          
          await prefs.setBool('test_data_added', true);
          debugPrint('为test@h.com账户添加测试数据成功');
        }
      } catch (e) {
        debugPrint('为test@h.com账户添加测试数据失败: $e');
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MyAppContent(),
    );
  }
}

/// 应用初始页面
/// 检查用户会话，决定显示登录页面还是主页
class InitialPage extends StatelessWidget {
  const InitialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkUserSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 显示启动画面或加载指示器
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          final hasSession = snapshot.data ?? false;
          if (hasSession) {
            // 有已登录用户，导航到主页
            return const ResponsiveNavigation();
          } else {
            // 没有已登录用户，导航到登录页面
            return const LoginPage();
          }
        }
      },
    );
  }

  /// 检查用户会话
  Future<bool> _checkUserSession() async {
    try {
      // 从SharedPreferences获取用户会话信息
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final email = prefs.getString('user_email');
      final username = prefs.getString('user_username');

      // 如果有会话信息，返回true，否则返回false
      return Future.delayed(
        const Duration(milliseconds: 1000),
        () => userId != null && email != null && username != null,
      );
    } catch (e) {
      return false;
    }
  }
}

class MyAppContent extends ConsumerWidget {
  const MyAppContent({super.key});

  @override
  Widget build(BuildContext, WidgetRef ref) {
    // 监听主题状态变化，包括themeType
    final themeState = ref.watch(themeProvider);
    
    // 强制MaterialApp重新构建当主题类型变化时
    return MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => RecycleBinBloc()),
            BlocProvider(
                create: (context) => TodoBloc(context.read<RecycleBinBloc>())),
            BlocProvider(
                create: (context) => HabitBloc(context.read<RecycleBinBloc>())),
            BlocProvider(create: (context) => PomodoroBloc()),
            BlocProvider(
                create: (context) => DiaryBloc(context.read<RecycleBinBloc>())),
            BlocProvider(create: (_) => HabitReminderBloc()),

            BlocProvider(create: (_) => AchievementBloc()),
            BlocProvider(create: (context) => DashboardBloc(
              context.read<HabitBloc>(),
              context.read<TodoBloc>(),
              context.read<DiaryBloc>(),
            )),
            BlocProvider(create: (_) => SecurityBloc()),
            BlocProvider(
                create: (context) =>
                    CategoryBloc(context.read<RecycleBinBloc>())),
          ],
          child: MaterialApp(
            key: ValueKey(themeState.themeType), // 使用主题类型作为key，强制重新构建
            title: '拾光记 - MomentKeep',
            // 每次构建时重新获取主题，确保使用最新的主题类型
            theme: AppTheme.materialTheme,
            darkTheme: AppTheme.darkMaterialTheme,
            themeMode: themeState.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const InitialPage(),
              '/home': (context) => const ResponsiveNavigation(),
              '/login': (context) => const LoginPage(),
              '/register': (context) => const RegisterPage(),
              '/forgot_password': (context) => const ForgotPasswordPage(),
            },
            debugShowCheckedModeBanner: false,
            // 添加路由观察者，用于监听页面可见性变化
            navigatorObservers: [routeObserver],
            // 应用程序级别的无障碍支持控制
            builder: (context, child) {
              return Semantics(
                container: true,
                // 仅在Windows平台上禁用无障碍支持，解决无障碍树崩溃问题
                enabled: defaultTargetPlatform != TargetPlatform.windows,
                child: child!,
              );
            },
            // 添加必要的本地化委托
            localizationsDelegates: [
              // 用于Material组件的本地化
              GlobalMaterialLocalizations.delegate,
              // 用于Widgets的本地化
              GlobalWidgetsLocalizations.delegate,
              // 用于Cupertino组件的本地化
              GlobalCupertinoLocalizations.delegate,
              // 用于FlutterQuill组件的本地化
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: [
              const Locale('zh', 'CN'),
              const Locale('en', 'US'),
            ],
          ),
        );
  }
}
