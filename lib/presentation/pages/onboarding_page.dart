import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 新手引导页
class OnboardingPage extends StatefulWidget {
  /// 完成回调
  final VoidCallback onComplete;

  const OnboardingPage({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.fitness_center,
      iconColor: const Color(0xFF4CAF50),
      title: '习惯打卡',
      description: '创建并追踪你的日常习惯\n培养良好习惯，成就更好自己',
      features: ['每日提醒提醒', '连续打卡统计', '打卡热力图', '积分奖励'],
    ),
    _OnboardingData(
      icon: Icons.checklist,
      iconColor: const Color(0xFF2196F3),
      title: '待办事项',
      description: '高效管理你的任务和时间\n再也不怕忘记重要事情',
      features: ['优先级设置', '子任务分解', '重复任务', '日历视图'],
    ),
    _OnboardingData(
      icon: Icons.menu_book,
      iconColor: const Color(0xFFFF9800),
      title: '日记记录',
      description: '记录生活点滴和感悟\n留住每一个珍贵瞬间',
      features: ['富文本编辑器', '图片/视频/音频', '手绘涂鸦', '心情追踪'],
    ),
    _OnboardingData(
      icon: Icons.timer,
      iconColor: const Color(0xFF9C27B0),
      title: '番茄钟',
      description: '专注工作，高效学习\n让时间为你所用',
      features: ['专注计时', '统计分析', '音频反馈', '全屏模式'],
    ),
    _OnboardingData(
      icon: Icons.stars,
      iconColor: const Color(0xFFFFC107),
      title: '积分商城',
      description: '完成任务获得积分\n兑换心仪奖励',
      features: ['积分获取', '商品兑换', '优惠券', '成就系统'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentData = _pages[_currentPage];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('跳过'),
              ),
            ),

            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final data = _pages[index];
                  return _buildPage(content: data);
                },
              ),
            ),

            // 指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildIndicator(index),
              ),
            ),
            const SizedBox(height: 16),

            // 下一步/开始按钮
            Padding(
              padding: const EdgeInsets.all(32),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < _pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _completeOnboarding();
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  _currentPage < _pages.length - 1 ? '下一步' : '开始使用',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({required _OnboardingData content}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 大图标
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: content.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              content.icon,
              size: 80,
              color: content.iconColor,
            ),
          ),
          const SizedBox(height: 40),

          // 标题
          Text(
            content.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            content.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // 功能列表
          ...content.features.map((feature) => _buildFeatureItem(feature)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            feature,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final theme = Theme.of(context);
    final isSelected = index == _currentPage;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isSelected ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.primary 
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<String> features;

  _OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.features,
  });
}
