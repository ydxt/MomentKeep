import 'package:flutter/material.dart';

/// 响应式工具类，提供屏幕尺寸断点和响应式布局辅助方法
class ResponsiveUtils {
  /// 屏幕尺寸断点定义
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// 判断当前屏幕是否为移动端
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// 判断当前屏幕是否为平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// 判断当前屏幕是否为桌面端
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// 判断当前屏幕是否为PC平台（桌面或平板）
  static bool isPC(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// 根据屏幕尺寸返回响应式宽度
  /// [context] 上下文
  /// [mobile] 移动端宽度（百分比）
  /// [tablet] 平板端宽度（百分比）
  /// [desktop] 桌面端宽度（百分比）
  static double getResponsiveWidth(
    BuildContext context,
    double mobile,
    double tablet,
    double desktop,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return width * mobile;
    } else if (width < tabletBreakpoint) {
      return width * tablet;
    } else {
      return width * desktop;
    }
  }

  /// 根据屏幕尺寸返回响应式高度
  /// [context] 上下文
  /// [mobile] 移动端高度（百分比）
  /// [tablet] 平板端高度（百分比）
  /// [desktop] 桌面端高度（百分比）
  static double getResponsiveHeight(
    BuildContext context,
    double mobile,
    double tablet,
    double desktop,
  ) {
    final height = MediaQuery.of(context).size.height;
    if (height < mobileBreakpoint) {
      return height * mobile;
    } else if (height < tabletBreakpoint) {
      return height * tablet;
    } else {
      return height * desktop;
    }
  }

  /// 根据屏幕尺寸返回响应式字体大小
  /// [context] 上下文
  /// [mobile] 移动端字体大小
  /// [tablet] 平板端字体大小
  /// [desktop] 桌面端字体大小
  static double getResponsiveFontSize(
    BuildContext context,
    double mobile,
    double tablet,
    double desktop,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile;
    } else if (width < tabletBreakpoint) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// 根据屏幕尺寸返回响应式内边距
  /// [context] 上下文
  /// [mobile] 移动端内边距
  /// [tablet] 平板端内边距
  /// [desktop] 桌面端内边距
  static EdgeInsets getResponsivePadding(
    BuildContext context,
    EdgeInsets mobile,
    EdgeInsets tablet,
    EdgeInsets desktop,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile;
    } else if (width < tabletBreakpoint) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// 根据屏幕尺寸返回响应式外边距
  /// [context] 上下文
  /// [mobile] 移动端外边距
  /// [tablet] 平板端外边距
  /// [desktop] 桌面端外边距
  static EdgeInsets getResponsiveMargin(
    BuildContext context,
    EdgeInsets mobile,
    EdgeInsets tablet,
    EdgeInsets desktop,
  ) {
    return getResponsivePadding(context, mobile, tablet, desktop);
  }

  /// 根据屏幕尺寸返回响应式边框半径
  /// [context] 上下文
  /// [mobile] 移动端边框半径
  /// [tablet] 平板端边框半径
  /// [desktop] 桌面端边框半径
  static double getResponsiveBorderRadius(
    BuildContext context,
    double mobile,
    double tablet,
    double desktop,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile;
    } else if (width < tabletBreakpoint) {
      return tablet;
    } else {
      return desktop;
    }
  }
}

/// 响应式容器组件，根据屏幕尺寸显示不同的子组件
class ResponsiveContainer extends StatelessWidget {
  /// 移动端子组件
  final Widget mobile;

  /// 平板端子组件
  final Widget? tablet;

  /// 桌面端子组件
  final Widget? desktop;

  /// 构造函数
  const ResponsiveContainer({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= ResponsiveUtils.desktopBreakpoint && desktop != null) {
      return desktop!;
    } else if (width >= ResponsiveUtils.mobileBreakpoint && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// 响应式网格视图，根据屏幕尺寸调整列数
class ResponsiveGridView extends StatelessWidget {
  /// 子组件列表
  final List<Widget> children;

  /// 移动端列数
  final int mobileCrossAxisCount;

  /// 平板端列数
  final int tabletCrossAxisCount;

  /// 桌面端列数
  final int desktopCrossAxisCount;

  /// 子组件间距
  final double crossAxisSpacing;

  /// 子组件行间距
  final double mainAxisSpacing;

  /// 子组件宽高比
  final double childAspectRatio;

  /// 构造函数
  const ResponsiveGridView({
    super.key,
    required this.children,
    this.mobileCrossAxisCount = 2,
    this.tabletCrossAxisCount = 3,
    this.desktopCrossAxisCount = 4,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;

    if (width >= ResponsiveUtils.desktopBreakpoint) {
      crossAxisCount = desktopCrossAxisCount;
    } else if (width >= ResponsiveUtils.mobileBreakpoint) {
      crossAxisCount = tabletCrossAxisCount;
    } else {
      crossAxisCount = mobileCrossAxisCount;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
