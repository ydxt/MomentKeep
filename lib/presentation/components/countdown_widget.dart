import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moment_keep/core/services/countdown_service.dart';

/// 倒计时日小组件，设计风格参考"Days Matter"
class CountdownWidget extends StatefulWidget {
  /// 目标日期
  final DateTime targetDate;

  /// 标题
  final String title;

  /// 描述
  final String? description;

  /// 背景颜色
  final Color backgroundColor;

  /// 文字颜色
  final Color textColor;

  /// 天数文字大小
  final double daysTextSize;

  /// 标题文字大小
  final double titleTextSize;

  /// 描述文字大小
  final double descriptionTextSize;

  /// 圆角半径
  final double borderRadius;

  /// 内边距
  final EdgeInsets padding;

  /// 构造函数
  const CountdownWidget({
    super.key,
    required this.targetDate,
    required this.title,
    this.description,
    this.backgroundColor = const Color(0xFFE8F5E9),
    this.textColor = const Color(0xFF2E7D32),
    this.daysTextSize = 48.0,
    this.titleTextSize = 16.0,
    this.descriptionTextSize = 12.0,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  /// 倒计时服务
  final CountdownService _countdownService = CountdownService();

  /// 计时器
  Timer? _timer;

  /// 当前天数
  int _days = 0;

  @override
  void initState() {
    super.initState();

    // 计算初始天数
    _calculateDays();

    // 启动计时器，每分钟更新一次
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _calculateDays();
    });
  }

  @override
  void dispose() {
    // 取消计时器
    _timer?.cancel();
    super.dispose();
  }

  /// 计算距离目标日期的天数
  void _calculateDays() {
    final days = _countdownService.calculateDaysUntil(widget.targetDate);
    if (days != _days) {
      setState(() {
        _days = days;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算文字样式
    final daysTextStyle = TextStyle(
      fontSize: widget.daysTextSize,
      fontWeight: FontWeight.bold,
      color: widget.textColor,
    );

    final titleTextStyle = TextStyle(
      fontSize: widget.titleTextSize,
      fontWeight: FontWeight.w600,
      color: widget.textColor,
    );

    final descriptionTextStyle = TextStyle(
      fontSize: widget.descriptionTextSize,
      color: widget.textColor.withOpacity(0.8),
    );

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 天数显示
          Text(
            _days > 0 ? '$_days' : '0',
            style: daysTextStyle,
          ),
          const SizedBox(height: 8),

          // 天数单位
          Text(
            _days == 1 ? '天' : '天',
            style: titleTextStyle,
          ),
          const SizedBox(height: 12),

          // 标题
          Text(
            widget.title,
            style: titleTextStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // 描述
          if (widget.description != null)
            Text(
              widget.description!,
              style: descriptionTextStyle,
              textAlign: TextAlign.center,
            ),

          // 目标日期
          Text(
            '${widget.targetDate.year}年${widget.targetDate.month}月${widget.targetDate.day}日',
            style: descriptionTextStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 倒计时日卡片组件，带有点击事件
class CountdownCardWidget extends StatelessWidget {
  /// 目标日期
  final DateTime targetDate;

  /// 标题
  final String title;

  /// 描述
  final String? description;

  /// 背景颜色
  final Color backgroundColor;

  /// 文字颜色
  final Color textColor;

  /// 点击事件
  final VoidCallback? onTap;

  /// 构造函数
  const CountdownCardWidget({
    super.key,
    required this.targetDate,
    required this.title,
    this.description,
    this.backgroundColor = const Color(0xFFE3F2FD),
    this.textColor = const Color(0xFF1565C0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CountdownWidget(
        targetDate: targetDate,
        title: title,
        description: description,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
    );
  }
}

/// 倒计时日列表组件
class CountdownListWidget extends StatelessWidget {
  /// 倒计时项列表
  final List<CountdownItem> items;

  /// 构造函数
  const CountdownListWidget({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: CountdownCardWidget(
            targetDate: item.targetDate,
            title: item.title,
            description: item.description,
            backgroundColor: item.backgroundColor,
            textColor: item.textColor,
            onTap: item.onTap,
          ),
        );
      },
    );
  }
}

/// 倒计时项数据类
class CountdownItem {
  /// 目标日期
  final DateTime targetDate;

  /// 标题
  final String title;

  /// 描述
  final String? description;

  /// 背景颜色
  final Color backgroundColor;

  /// 文字颜色
  final Color textColor;

  /// 点击事件
  final VoidCallback? onTap;

  /// 构造函数
  const CountdownItem({
    required this.targetDate,
    required this.title,
    this.description,
    this.backgroundColor = const Color(0xFFE8F5E9),
    this.textColor = const Color(0xFF2E7D32),
    this.onTap,
  });
}
