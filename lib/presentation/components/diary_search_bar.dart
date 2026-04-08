import 'package:flutter/material.dart';

/// 日记搜索栏组件
class DiarySearchBar extends StatefulWidget {
  /// 搜索变化回调
  final Function(String query) onSearchChanged;
  
  /// 清除搜索回调
  final VoidCallback? onClear;

  const DiarySearchBar({
    Key? key,
    required this.onSearchChanged,
    this.onClear,
  }) : super(key: key);

  @override
  State<DiarySearchBar> createState() => _DiarySearchBarState();
}

class _DiarySearchBarState extends State<DiarySearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    
    // 监听输入变化
    _controller.addListener(() {
      widget.onSearchChanged(_controller.text);
      setState(() {
        _isSearching = _controller.text.isNotEmpty;
      });
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: '搜索日记标题、内容或标签...',
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          // 可以在这里添加额外的搜索逻辑
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// 搜索结果显示组件
class SearchResultIndicator extends StatelessWidget {
  /// 当前显示的搜索结果数量
  final int resultCount;
  
  /// 总日记数量
  final int totalCount;
  
  /// 搜索关键词
  final String query;

  const SearchResultIndicator({
    Key? key,
    required this.resultCount,
    required this.totalCount,
    required this.query,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '找到 $resultCount 条结果（共 $totalCount 条）',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (query.isNotEmpty)
            Text(
              '关键词: "$query"',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
