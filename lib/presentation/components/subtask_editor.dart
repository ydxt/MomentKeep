import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/subtask.dart';

/// 子任务编辑器组件
class SubtaskEditor extends StatefulWidget {
  /// 子任务列表
  final List<Subtask> subtasks;

  /// 子任务变化回调
  final Function(List<Subtask>) onChanged;

  const SubtaskEditor({
    Key? key,
    required this.subtasks,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<SubtaskEditor> createState() => _SubtaskEditorState();
}

class _SubtaskEditorState extends State<SubtaskEditor> {
  late List<Subtask> _subtasks;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subtasks = List.from(widget.subtasks);
  }

  /// 添加子任务
  void _addSubtask() {
    if (_controller.text.trim().isEmpty) return;

    final newSubtask = Subtask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      todoId: '', // 将在保存时设置
      title: _controller.text.trim(),
      isCompleted: false,
      orderIndex: _subtasks.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _subtasks.add(newSubtask);
      _controller.clear();
    });

    widget.onChanged(_subtasks);
  }

  /// 切换子任务完成状态
  void _toggleSubtask(int index) {
    setState(() {
      _subtasks[index] = _subtasks[index].copyWith(
        isCompleted: !_subtasks[index].isCompleted,
        updatedAt: DateTime.now(),
      );
    });
    widget.onChanged(_subtasks);
  }

  /// 删除子任务
  void _deleteSubtask(int index) {
    setState(() {
      _subtasks.removeAt(index);
      // 重新排序
      _subtasks = _subtasks.asMap().entries.map((e) {
        return e.value.copyWith(orderIndex: e.key);
      }).toList();
    });
    widget.onChanged(_subtasks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = _subtasks.where((s) => s.isCompleted).length;
    final totalCount = _subtasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Icon(Icons.checklist, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '子任务 ($completedCount/$totalCount)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 进度条
        if (totalCount > 0) ...[
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
        ],

        // 子任务列表
        ..._subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final subtask = entry.value;
          return _buildSubtaskItem(subtask, index, theme);
        }),

        // 添加子任务输入框
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '添加子任务...',
                  prefixIcon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.check),
              onPressed: _addSubtask,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubtaskItem(Subtask subtask, int index, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Checkbox(
            value: subtask.isCompleted,
            onChanged: (_) => _toggleSubtask(index),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              subtask.title,
              style: TextStyle(
                decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                color: subtask.isCompleted
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
            onPressed: () => _deleteSubtask(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
