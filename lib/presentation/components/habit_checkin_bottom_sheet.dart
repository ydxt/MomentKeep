import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';

/// 习惯打卡底部工作表
///
/// 采用极简主义设计，提供优雅的打卡评分体验
class HabitCheckInBottomSheet extends StatefulWidget {
  /// 习惯对象
  final Habit habit;

  /// 习惯分类
  final Category? category;

  /// 保存回调
  final Function(int score, List<ContentBlock> comment) onSave;

  const HabitCheckInBottomSheet({
    super.key,
    required this.habit,
    this.category,
    required this.onSave,
  });

  @override
  State<HabitCheckInBottomSheet> createState() =>
      _HabitCheckInBottomSheetState();
}

class _HabitCheckInBottomSheetState extends State<HabitCheckInBottomSheet>
    with SingleTickerProviderStateMixin {
  /// 当前评分
  int _rating = 3;

  /// 自定义评分输入控制器
  final TextEditingController _customRatingController = TextEditingController();

  /// 备注内容
  List<ContentBlock> _comment = [];

  /// 动画控制器
  late AnimationController _animationController;

  /// 缩放动画
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 设置初始评分和自定义评分控制器
    _rating = (widget.habit.fullStars * 0.8).round(); // 默认评分为满星数的80%
    _customRatingController.text = _rating.toString();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _customRatingController.dispose();
    super.dispose();
  }

  /// 触发评分变化动画
  void _triggerRatingAnimation() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // 触觉反馈
    HapticFeedback.selectionClick();
  }

  /// 处理星星点击事件
  void _handleStarTap(int rating) {
    setState(() {
      _rating = rating;
    });
    _triggerRatingAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final isPC = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isPC ? 32 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 顶部指示条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              SizedBox(height: isPC ? 32 : 24),

              // 习惯名称（大号字居中）
              Text(
                widget.habit.name,
                style: TextStyle(
                  fontSize: isPC ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepSpaceGray,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isPC ? 16 : 12),

              // 习惯分类标签
              if (widget.category != null)
                _buildCategoryChip(widget.category!, isPC),

              // 周期计分进度提示
              if (widget.habit.scoringMode != ScoringMode.daily)
                _buildCycleProgressIndicator(isPC),

              SizedBox(height: isPC ? 40 : 32),

              // 评分标题
              Text(
                widget.habit.type == HabitType.negative ? '本次情况' : '本次打卡质量',
                style: TextStyle(
                  fontSize: isPC ? 18 : 16,
                  fontWeight: FontWeight.w500,
                  color: widget.habit.type == HabitType.negative ? Colors.red[700] : Colors.grey[700],
                ),
              ),

              SizedBox(height: isPC ? 24 : 20),

              // 根据满星数显示不同的评分界面
              widget.habit.fullStars <= 10
                  ? Column(
                      children: [
                        // 传统星星点击界面
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(widget.habit.fullStars,
                                    (index) {
                                  final starRating = index + 1;
                                  return GestureDetector(
                                    onTap: () {
                                      _handleStarTap(starRating);
                                    },
                                    child: Icon(
                                      starRating <= _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: isPC ? 48 : 40,
                                      color: widget.habit.type == HabitType.negative 
                                          ? const Color(0xFFEF4444) 
                                          : const Color(0xFFFFD700),
                                      // 添加点击反馈
                                      semanticLabel: '$starRating 星',
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: isPC ? 20 : 16),

                        // 评分数值显示
                        Text(
                          '$_rating 星',
                          style: TextStyle(
                            fontSize: isPC ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: widget.habit.type == HabitType.negative 
                                ? const Color(0xFFEF4444) 
                                : AppTheme.secondaryColor,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // 评分说明
                        Text(
                          '请输入本次打卡的评分（1-${widget.habit.fullStars}）',
                          style: TextStyle(
                            fontSize: isPC ? 16 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isPC ? 20 : 16),

                        // 数字输入框
                        SizedBox(
                          width: isPC ? 120 : 100,
                          child: TextField(
                            controller: _customRatingController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isPC ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              color: widget.habit.type == HabitType.negative 
                                  ? const Color(0xFFEF4444) 
                                  : const Color(0xFFFFD700),
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: widget.habit.type == HabitType.negative 
                                      ? const Color(0xFFEF4444) 
                                      : const Color(0xFFFFD700),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: widget.habit.type == HabitType.negative 
                                      ? const Color(0xFFEF4444) 
                                      : const Color(0xFFFFD700),
                                  width: 3,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: isPC ? 16 : 12,
                              ),
                            ),
                            onChanged: (value) {
                              final int? customValue = int.tryParse(value);
                              if (customValue != null &&
                                  customValue >= 1 &&
                                  customValue <= widget.habit.fullStars) {
                                setState(() {
                                  _rating = customValue;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(height: isPC ? 16 : 12),

                        // 评分范围提示
                        Text(
                          '满星: ${widget.habit.fullStars} 星',
                          style: TextStyle(
                            fontSize: isPC ? 16 : 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: isPC ? 20 : 16),

                        // 快捷评分按钮
                        Wrap(
                          spacing: isPC ? 12 : 8,
                          runSpacing: isPC ? 12 : 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (int i = 1; i <= 5; i++)
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _rating = i;
                                    _customRatingController.text = i.toString();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _rating == i
                                      ? (widget.habit.type == HabitType.negative 
                                          ? const Color(0xFFEF4444) 
                                          : const Color(0xFFFFD700))
                                      : Colors.grey[200],
                                  foregroundColor: _rating == i
                                      ? Colors.white
                                      : Colors.grey[800],
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isPC ? 20 : 16,
                                    vertical: isPC ? 12 : 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  '$i 星',
                                  style: TextStyle(
                                    fontSize: isPC ? 14 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _rating = widget.habit.fullStars ~/ 2;
                                  _customRatingController.text =
                                      _rating.toString();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _rating == widget.habit.fullStars ~/ 2
                                        ? (widget.habit.type == HabitType.negative 
                                            ? const Color(0xFFEF4444) 
                                            : const Color(0xFFFFD700))
                                        : Colors.grey[200],
                                foregroundColor:
                                    _rating == widget.habit.fullStars ~/ 2
                                        ? Colors.white
                                        : Colors.grey[800],
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPC ? 20 : 16,
                                  vertical: isPC ? 12 : 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '${widget.habit.fullStars ~/ 2} 星',
                                style: TextStyle(
                                  fontSize: isPC ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _rating = widget.habit.fullStars;
                                  _customRatingController.text =
                                      _rating.toString();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _rating == widget.habit.fullStars
                                        ? (widget.habit.type == HabitType.negative 
                                            ? const Color(0xFFEF4444) 
                                            : const Color(0xFFFFD700))
                                        : Colors.grey[200],
                                foregroundColor:
                                    _rating == widget.habit.fullStars
                                        ? Colors.white
                                        : Colors.grey[800],
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPC ? 20 : 16,
                                  vertical: isPC ? 12 : 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '${widget.habit.fullStars} 星',
                                style: TextStyle(
                                  fontSize: isPC ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

              SizedBox(height: isPC ? 32 : 24),

              // 备注输入区域
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '记录本次打卡感受或遇到的困难...',
                  style: TextStyle(
                    fontSize: isPC ? 16 : 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              SizedBox(height: isPC ? 12 : 8),

              // 富文本编辑器
              Container(
                constraints: BoxConstraints(
                  maxHeight: isPC ? 200 : 150,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: RichTextEditor(
                  initialContent: _comment,
                  onContentChanged: (content) {
                    _comment = content;
                  },
                  readOnly: false,
                ),
              ),

              SizedBox(height: isPC ? 32 : 24),

              // 操作按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 取消按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[800],
                        padding: EdgeInsets.symmetric(
                          vertical: isPC ? 18 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isPC ? 16 : 12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: isPC ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 确定按钮
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onSave(_rating, _comment);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: AppTheme.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isPC ? 18 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isPC ? 16 : 12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '确定',
                        style: TextStyle(
                          fontSize: isPC ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryChip(Category category, bool isPC) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPC ? 20 : 16,
        vertical: isPC ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Color(category.color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(isPC ? 24 : 20),
        border: Border.all(
          color: Color(category.color).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          color: Color(category.color),
          fontSize: isPC ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建周期计分进度指示器
  Widget _buildCycleProgressIndicator(bool isPC) {
    final habit = widget.habit;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isTodayChecked = habit.history.contains(today.toIso8601String().split('T')[0]);

    // 计算周期开始时间（逻辑需与 Bloc 一致）
    DateTime cycleStart;
    if (habit.scoringMode == ScoringMode.weekly) {
      final weekday = now.weekday; // 1 = Monday
      cycleStart = today.subtract(Duration(days: weekday - 1));
    } else {
      final daysSinceCreation = now.difference(habit.createdAt).inDays;
      final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
      cycleStart = habit.createdAt.add(Duration(days: cycleIndex * habit.customCycleDays));
    }

    // 强制归一化周期开始时间为 00:00:00
    cycleStart = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);

    // 统计周期内打卡次数
    final recordsInCycle = habit.checkInRecords.where((record) {
      final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      return !rDate.isBefore(cycleStart);
    }).length;
    final currentCount = isTodayChecked ? recordsInCycle : recordsInCycle + 1; // +1 为本次打卡

    final target = habit.targetDays;
    final progress = (currentCount / target).clamp(0.0, 1.0);
    final remaining = target - currentCount;
    final isCompleted = currentCount >= target;

    // 检查是否已经发奖
    final bool alreadyRewarded = habit.lastCycleRewardTime != null &&
        (habit.lastCycleRewardTime!.isAtSameMomentAs(cycleStart) || habit.lastCycleRewardTime!.isAfter(cycleStart));

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(isPC ? 16 : 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCompleted ? '🎉 本周期已达标！' : '🔥 周期进度',
                style: TextStyle(
                  color: isCompleted ? Colors.green : Colors.blue,
                  fontSize: isPC ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (habit.cycleRewardPoints > 0)
                Text(
                  '+${habit.cycleRewardPoints} 分',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: isPC ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : Colors.blue),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            alreadyRewarded
                ? '本期已发奖励，下期继续努力！'
                : (isCompleted
                    ? '本周期已打卡 $currentCount 天，达标！'
                    : '本周期已打卡 $currentCount 天，还差 $remaining 天获得积分'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isPC ? 12 : 11,
            ),
          ),
        ],
      ),
    );
  }
}
