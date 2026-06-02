import 'package:flutter/material.dart';

/// 骨架屏加载组件
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    Key? key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.5 + (value * 0.5),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// 待办列表骨架屏
class TodoListSkeleton extends StatelessWidget {
  const TodoListSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              // 复选框骨架
              const SkeletonLoader(
                width: 24,
                height: 24,
                borderRadius: 4,
              ),
              const SizedBox(width: 12),
              
              // 文本骨架
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: double.infinity),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 习惯卡片骨架屏
class HabitCardSkeleton extends StatelessWidget {
  const HabitCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标骨架
            const SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: 24,
            ),
            const SizedBox(width: 16),
            
            // 文本骨架
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(width: 150),
                  const SizedBox(height: 8),
                  const SkeletonLoader(width: 100, height: 12),
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 8,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日记卡片骨架屏
class DiaryCardSkeleton extends StatelessWidget {
  const DiaryCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoader(width: 100, height: 12),
            const SizedBox(height: 12),
            const SkeletonLoader(width: double.infinity),
            const SizedBox(height: 8),
            SkeletonLoader(
              width: MediaQuery.of(context).size.width * 0.7,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SkeletonLoader(width: 60, height: 20, borderRadius: 10),
                const SizedBox(width: 8),
                const SkeletonLoader(width: 60, height: 20, borderRadius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
