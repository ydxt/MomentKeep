import 'package:flutter/material.dart';

class AppSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String query) onSearchChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final String? initialText;

  const AppSearchBar({
    super.key,
    this.hintText = '搜索...',
    required this.onSearchChanged,
    this.onClear,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.initialText,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _controller.text = widget.initialText!;
      _isSearching = true;
    }
    _controller.addListener(() {
      widget.onSearchChanged(_controller.text);
      setState(() {
        _isSearching = _controller.text.isNotEmpty;
      });
    });
  }

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
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        onTap: () {
          if (widget.readOnly) {
            _focusNode.unfocus();
          }
          widget.onTap?.call();
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
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
        onSubmitted: (value) {},
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

class SearchResultIndicator extends StatelessWidget {
  final int resultCount;
  final int totalCount;
  final String query;

  const SearchResultIndicator({
    super.key,
    required this.resultCount,
    required this.totalCount,
    required this.query,
  });

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
