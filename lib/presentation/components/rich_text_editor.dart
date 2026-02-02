import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/presentation/pages/diary/editor_controller.dart';
import 'package:moment_keep/presentation/pages/diary/block_editor.dart';

/// 富媒体编辑器组件 - 使用新的BlockEditor实现
class RichTextEditor extends StatefulWidget {
  /// 初始内容块列表
  final List<ContentBlock> initialContent;

  /// 内容变化回调
  final Function(List<ContentBlock>) onContentChanged;

  /// 是否只读
  final bool readOnly;

  /// 是否为题库模式
  final bool isQuestionBank;

  /// 构造函数
  const RichTextEditor({
    super.key,
    this.initialContent = const [],
    required this.onContentChanged,
    this.readOnly = false,
    this.isQuestionBank = false,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late EditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
        initialBlocks:
            widget.initialContent.isNotEmpty ? widget.initialContent : null);
    _controller.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    widget.onContentChanged(_controller.blocks);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      // For read-only mode, just display the content without editing capabilities
      return Container(
        constraints: const BoxConstraints(minHeight: 200),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: BlockEditor(
          controller: _controller,
          isQuestionBank: widget.isQuestionBank,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: BlockEditor(
        controller: _controller,
        isQuestionBank: widget.isQuestionBank,
      ),
    );
  }
}
