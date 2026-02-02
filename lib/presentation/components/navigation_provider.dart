import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 导航状态Notifier类
class NavigationNotifier extends Notifier<int> {
  @override
  int build() {
    return 0; // 初始选中首页
  }

  /// 设置当前选中的页面索引
  void setIndex(int index) {
    state = index;
  }
}

/// 导航状态提供者实例
final navigationProvider = NotifierProvider<NavigationNotifier, int>(() {
  return NavigationNotifier();
});
