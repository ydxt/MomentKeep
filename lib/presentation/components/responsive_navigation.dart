import 'package:flutter/material.dart';
import 'package:moment_keep/presentation/pages/home_page.dart';
import 'package:moment_keep/presentation/pages/todo_page.dart';
import 'package:moment_keep/presentation/pages/habit_page.dart';
import 'package:moment_keep/presentation/pages/pomodoro_page.dart';
import 'package:moment_keep/presentation/pages/diary_page.dart';
import 'package:moment_keep/presentation/pages/dashboard_page.dart';
import 'package:moment_keep/presentation/pages/user_info_page.dart';
import 'package:moment_keep/presentation/pages/recycle_bin_page.dart';
import 'package:moment_keep/presentation/pages/star_exchange_page.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/components/navigation_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 响应式导航组件，根据屏幕尺寸自动切换导航模式
class ResponsiveNavigation extends ConsumerStatefulWidget {
  /// 构造函数
  const ResponsiveNavigation({super.key});

  @override
  ConsumerState<ResponsiveNavigation> createState() =>
      _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends ConsumerState<ResponsiveNavigation> {
  /// 页面列表
  final List<Widget> _pages = [
    HomePage(),
    TodoPage(),
    HabitPage(),
    DiaryPage(),
    PomodoroPage(), // 番茄钟
    DashboardPage(), // 数据统计
    StarExchangePage(), // 积分兑换
    RecycleBinPage(), // 回收站
    UserInfoPage(), // 个人中心
  ];

  /// 导航项配置
  final List<Map<String, dynamic>> _navItems = [
    {
      'title': '首页',
      'icon': Icons.home,
    },
    {
      'title': '待办事项',
      'icon': Icons.checklist,
    },
    {
      'title': '习惯',
      'icon': Icons.track_changes,
    },
    {
      'title': '日记',
      'icon': Icons.book,
    },
    {
      'title': '番茄钟',
      'icon': Icons.access_alarm,
    },
    {
      'title': '数据统计',
      'icon': Icons.analytics,
    },
    {
      'title': '积分兑换',
      'icon': Icons.shopping_bag,
    },
    {
      'title': '回收站',
      'icon': Icons.delete,
    },
    {
      'title': '个人中心',
      'icon': Icons.person,
    },
  ];

  /// 移动端导航项索引（只显示前5个）
  final List<int> _mobileNavIndices = [0, 1, 2, 3, 8]; // 首页、待办事项、习惯、日记、个人中心

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final selectedIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: Row(
        children: [
          // 侧边栏导航（仅在PC端显示）
          if (MediaQuery.of(context).size.width > 600)
            _buildSidebar(theme, isDarkMode, selectedIndex),
          // 主内容区域
          Expanded(
            child: Column(
              children: [
                // 主内容
                Expanded(
                  child: _pages[selectedIndex],
                ),
                // 底部导航栏（仅在移动端显示）
                if (MediaQuery.of(context).size.width <= 600)
                  _buildBottomNavigationBar(theme, isDarkMode, selectedIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建侧边栏导航
  Widget _buildSidebar(ThemeData theme, bool isDarkMode, int selectedIndex) {
    return SizedBox(
      width: 80, // 固定侧边栏宽度
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          ref.read(navigationProvider.notifier).setIndex(index);
        },
        labelType: NavigationRailLabelType.none, // 不显示标签文本
        extended: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        selectedIconTheme:
            IconThemeData(color: theme.colorScheme.secondary, size: 24),
        unselectedIconTheme: IconThemeData(
            color: theme.colorScheme.onSurface.withOpacity(0.6), size: 24),
        destinations: _navItems
            .map((item) => NavigationRailDestination(
                  icon: Tooltip(
                    message: item['title'] as String,
                    child: Icon(item['icon'] as IconData),
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(8),
                    showDuration: const Duration(seconds: 2),
                    waitDuration: const Duration(milliseconds: 200),
                  ),
                  label: Text(item['title'] as String),
                ))
            .toList(),
        // 移除leading和trailing，简化侧边栏
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(ThemeData theme, bool isDarkMode, int selectedIndex) {
    // 移动端只显示前5个导航项：首页、待办事项、习惯、日记、设置
    final mobileNavItems = _mobileNavIndices.map((index) => _navItems[index]).toList();
    
    // 将原始selectedIndex转换为移动端导航项的索引
    final mobileSelectedIndex = _mobileNavIndices.indexOf(selectedIndex);
    
    return BottomNavigationBar(
      items: mobileNavItems
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item['icon'] as IconData),
                label: item['title'] as String,
              ))
          .toList(),
      currentIndex: mobileSelectedIndex >= 0 ? mobileSelectedIndex : 0,
      selectedItemColor: theme.colorScheme.secondary,
      unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
      backgroundColor: theme.scaffoldBackgroundColor,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        // 将移动端导航项索引转换为原始索引
        final originalIndex = _mobileNavIndices[index];
        ref.read(navigationProvider.notifier).setIndex(originalIndex);
      },
      selectedFontSize: 12,
      unselectedFontSize: 10,
      iconSize: 24,
    );
  }
}
