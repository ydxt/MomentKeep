import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/core/utils/habit_date_utils.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/rich_text_editor.dart';

class HabitCheckInDialog extends StatefulWidget {
  final Habit habit;
  final DateTime? date;

  const HabitCheckInDialog({
    super.key,
    required this.habit,
    this.date,
  });

  @override
  State<HabitCheckInDialog> createState() => _HabitCheckInDialogState();
}

class _HabitCheckInDialogState extends State<HabitCheckInDialog> {
  late TextEditingController _scoreController;
  late List<ContentBlock> _commentContent;

  @override
  void initState() {
    super.initState();

    final targetDate = widget.date ?? DateTime.now();
    final targetDateStr = targetDate.toIso8601String().split('T')[0];

    final existingRecord = widget.habit.checkInRecords.firstWhere(
      (record) {
        final recordDate = record.timestamp.toIso8601String().split('T')[0];
        return recordDate == targetDateStr;
      },
      orElse: () => CheckInRecord(
        id: '',
        habitId: widget.habit.id,
        score: (widget.habit.scoringMode == ScoringMode.checkInWithPenalty || widget.habit.scoringMode == ScoringMode.weeklyWithPenalty)
            ? widget.habit.checkInPoints
            : widget.habit.fullStars,
        comment: [],
        timestamp: targetDate,
      ),
    );

    final displayScore = widget.habit.type == HabitType.negative
        ? existingRecord.score.abs()
        : existingRecord.score;
    _scoreController = TextEditingController(
      text: displayScore.toString(),
    );

    _commentContent = existingRecord.comment;
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  void _saveCheckIn() {
    final int score = int.tryParse(_scoreController.text) ?? 0;

    if (score < 1 || score > widget.habit.fullStars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('得分必须在1到${widget.habit.fullStars}之间'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final int finalScore =
        widget.habit.type == HabitType.negative ? -score : score;

    context.read<HabitBloc>().add(RecordHabitCompletion(
          widget.habit.id,
          finalScore,
          _commentContent,
          date: widget.date,
        ));

    Navigator.pop(context);

    final isToday = widget.date == null ||
        HabitDateUtils.isSameDay(widget.date!, DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${widget.habit.name} ${isToday ? (widget.habit.type == HabitType.negative ? '记录' : '打卡') : '补卡'}成功！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = widget.habit.type == HabitType.negative;
    final primaryColor =
        isNegative ? theme.colorScheme.error : theme.colorScheme.primary;
    final isToday = widget.date == null ||
        HabitDateUtils.isSameDay(widget.date!, DateTime.now());

    return AlertDialog(
      title: Text(
          '${isToday ? (isNegative ? '记录' : '打卡') : '补卡'}: ${widget.habit.name}'),
      backgroundColor: theme.colorScheme.surface,
      titleTextStyle: TextStyle(
        color: isNegative
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNegative ? '今天的扣分' : '今天的得分',
              style: TextStyle(
                color: isNegative
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '1-${widget.habit.fullStars}',
                      hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant,
                      prefixIcon: isNegative
                          ? Icon(Icons.remove, color: primaryColor)
                          : null,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '/${widget.habit.fullStars}',
                            style: TextStyle(color: primaryColor),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    style: TextStyle(
                      color: isNegative
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '写下你的感受',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: RichTextEditor(
                  initialContent: _commentContent,
                  onContentChanged: (content) {
                    setState(() {
                      _commentContent = content;
                    });
                  },
                  readOnly: false,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('取消',
              style:
                  TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: _saveCheckIn,
          child: Text('保存', style: TextStyle(color: primaryColor)),
        ),
      ],
    );
  }
}
