import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/presentation/blocs/search_bloc.dart';
import 'package:moment_keep/presentation/blocs/category_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/components/app_search_bar.dart';
import 'package:moment_keep/presentation/pages/habit_detail_dialog.dart';
import 'package:moment_keep/presentation/pages/todo_detail_page.dart';
import 'package:moment_keep/presentation/pages/product_detail_page.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';

class GlobalSearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;
  const GlobalSearchPage({super.key, this.initialQuery});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  String _currentQuery = '';
  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  static const List<String> _hotSearchTerms = ['虚拟商品', '积分兑换', '限时优惠', '新品上市', '热门好物'];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _currentQuery = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SearchBloc>().add(SearchAll(_currentQuery));
        setState(() {
          _getSuggestions(_currentQuery);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentThemeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: AppSearchBar(
          hintText: '搜索全部内容...',
          autofocus: widget.initialQuery == null,
          initialText: widget.initialQuery,
          onSearchChanged: (query) {
            _currentQuery = query;
            if (query.trim().isEmpty) {
              context.read<SearchBloc>().add(ClearSearch());
              setState(() {
                _suggestions = [];
              });
            } else {
              context.read<SearchBloc>().add(SearchAll(query));
              setState(() {
                _getSuggestions(query);
              });
            }
          },
          onClear: () {
            _currentQuery = '';
            context.read<SearchBloc>().add(ClearSearch());
          },
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (state is SearchInitial) {
            return _buildInitialContent(theme);
          }
          if (state is SearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SearchLoaded) {
            return _buildSearchResults(state, theme);
          }
          return _buildInitialContent(theme);
        },
      ),
    );
  }

  Widget _buildInitialContent(ThemeData theme) {
    return Column(
      children: [
        if (_suggestions.isNotEmpty)
          _buildSuggestionsList(theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_searchHistory.isNotEmpty) ...[
                  _buildSectionHeader('搜索历史', theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._searchHistory.map((term) => Chip(
                            label: Text(term, style: TextStyle(fontSize: 13)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeFromHistory(term),
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                          )),
                      InkWell(
                        onTap: _clearHistory,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                              const SizedBox(width: 4),
                              Text('清空', style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _buildSectionHeader('热门搜索', theme),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hotSearchTerms.map((term) => InkWell(
                    onTap: () => _performSearch(term),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, size: 16, color: theme.colorScheme.error),
                          const SizedBox(width: 4),
                          Text(term, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return InkWell(
            onTap: () => _performSearch(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(SearchLoaded state, ThemeData theme) {
    final results = state.results;
    final hasResults = results.values.any((list) => list.isNotEmpty);

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的结果',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (results['habits'] != null && results['habits']!.isNotEmpty)
          _buildModuleSection(
            icon: Icons.repeat,
            title: '习惯',
            theme: theme,
            results: results['habits']!,
            maxItems: 3,
            itemBuilder: (item) => _buildHabitItem(item as Habit, theme),
            onItemTap: (item) => _navigateToHabitDetail(item as Habit),
          ),
        if (results['todos'] != null && results['todos']!.isNotEmpty)
          _buildModuleSection(
            icon: Icons.check_circle_outline,
            title: 'Todo',
            theme: theme,
            results: results['todos']!,
            maxItems: 3,
            itemBuilder: (item) => _buildTodoItem(item as Todo, theme),
            onItemTap: (item) => _navigateToTodoDetail(item as Todo),
          ),
        if (results['diaries'] != null && results['diaries']!.isNotEmpty)
          _buildModuleSection(
            icon: Icons.book_outlined,
            title: '日记',
            theme: theme,
            results: results['diaries']!,
            maxItems: 3,
            itemBuilder: (item) => _buildDiaryItem(item as Journal, theme),
            onItemTap: (item) => _navigateToDiaryDetail(item as Journal),
          ),
        if (results['products'] != null && results['products']!.isNotEmpty)
          _buildModuleSection(
            icon: Icons.shopping_bag_outlined,
            title: '商品',
            theme: theme,
            results: results['products']!,
            maxItems: 3,
            itemBuilder: (item) => _buildProductItem(item as StarProduct, theme),
            onItemTap: (item) => _navigateToProductDetail(item as StarProduct),
          ),
      ],
    );
  }

  Widget _buildModuleSection({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required List<dynamic> results,
    required int maxItems,
    required Widget Function(dynamic) itemBuilder,
    required void Function(dynamic) onItemTap,
  }) {
    final displayItems = results.take(maxItems).toList();
    final hasMore = results.length > maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${results.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...displayItems.map((item) => InkWell(
              onTap: () => onItemTap(item),
              child: itemBuilder(item),
            )),
        if (hasMore)
          InkWell(
            onTap: () {
              context.read<SearchBloc>().add(SearchByModule(_currentQuery, _moduleKeyFromTitle(title)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  '查看更多',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
      ],
    );
  }

  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.add(query);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(_searchHistory.length - 10);
      }
    });
  }

  void _removeFromHistory(String query) {
    setState(() {
      _searchHistory.remove(query);
    });
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
    });
  }

  void _getSuggestions(String query) {
    final bloc = context.read<SearchBloc>();
    final state = bloc.state;
    if (state is SearchLoaded) {
      final products = state.results['products'] as List<StarProduct>? ?? [];
      final matchingNames = products
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .map((p) => p.name)
          .toSet()
          .toList();
      _suggestions = matchingNames.take(5).toList();
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    _addToHistory(query);
    context.read<SearchBloc>().add(SearchAll(query));
    setState(() {
      _suggestions = [];
    });
  }

  String _moduleKeyFromTitle(String title) {
    switch (title) {
      case '习惯':
        return 'habits';
      case 'Todo':
        return 'todos';
      case '日记':
        return 'diaries';
      case '商品':
        return 'products';
      default:
        return '';
    }
  }

  Widget _buildHabitItem(Habit habit, ThemeData theme) {
    final now = DateTime.now();
    final todayString = now.toIso8601String().split('T')[0];
    final isCompleted = habit.history.contains(todayString);
    final isNegative = habit.type == HabitType.negative;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNegative
            ? theme.colorScheme.error.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNegative
              ? theme.colorScheme.error
              : theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(habit.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(habit.icon),
                  color: Color(habit.color),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNegative
                              ? theme.colorScheme.error.withValues(alpha: 0.1)
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNegative ? Icons.trending_down : Icons.trending_up,
                              size: 10,
                              color: isNegative
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              isNegative
                                  ? '-${habit.fullStars}'
                                  : '+${habit.fullStars}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isNegative
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted
                        ? '${habit.currentStreak}天连续 • 已完成'
                        : '${habit.currentStreak}天连续 • 待完成',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isNegative
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCompleted ? '已完成' : '待完成',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isNegative
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Todo todo, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(
          color: todo.isCompleted ? Colors.transparent : theme.colorScheme.primary,
          width: 4,
        )),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) {},
                  activeColor: theme.colorScheme.primary,
                  checkColor: theme.colorScheme.onPrimary,
                  side: BorderSide(color: theme.colorScheme.outline, width: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: todo.isCompleted
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: todo.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        todo.date != null
                            ? '${todo.date!.month}/${todo.date!.day} ${todo.date!.hour}:${todo.date!.minute.toString().padLeft(2, '0')}'
                            : '未设置时间',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (todo.categoryId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.category, size: 12, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                todo.categoryId,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (todo.tags.isNotEmpty)
                        ...todo.tags.map((tag) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tag, size: 12, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(todo.priority, theme),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getPriorityLabel(todo.priority),
                        style: TextStyle(
                          color: _getPriorityColor(todo.priority, theme),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryItem(Journal diary, ThemeData theme) {
    final textContent = diary.content
        .where((block) => block.type == ContentBlockType.text)
        .map((block) => block.data)
        .join(' ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          diary.title.isNotEmpty ? diary.title : '无标题日记',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category,
                            color: theme.colorScheme.secondary,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(diary.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.edit_note, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  constraints: BoxConstraints(
                    minHeight: textContent.isNotEmpty ? 20 : 0,
                  ),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: textContent.isNotEmpty
                      ? Text(
                          textContent,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          '暂无文字内容',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ],
            ),
            if (diary.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: diary.tags.map((tag) => Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(StarProduct product, ThemeData theme) {
    final priceColor = product.isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: ImageLoaderService.getImageProvider(product.image),
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A4532),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  if (!product.isActive)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF102216).withValues(alpha: 0.4),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.description != null && product.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (product.points > 0) ...[
                        Icon(Icons.auto_awesome, size: 14, color: priceColor),
                        const SizedBox(width: 4),
                        Text(
                          '${product.points}积分',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: priceColor,
                          ),
                        ),
                      ] else
                        Text(
                          '¥${product.price}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: priceColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHabitDetail(Habit habit) async {
    final categoryBloc = context.read<CategoryBloc>();
    List<Category> categories = [];

    final categoryState = categoryBloc.state;
    if (categoryState is CategoryLoaded) {
      categories = categoryState.categories
          .where((c) => c.type == CategoryType.habit)
          .toList();
    }

    if (categories.isEmpty) {
      categoryBloc.add(const LoadCategories(type: CategoryType.habit));
      try {
        final state = await categoryBloc.stream
            .firstWhere((s) => s is CategoryLoaded)
            .timeout(const Duration(seconds: 3));
        if (state is CategoryLoaded) {
          categories = state.categories;
        }
      } catch (_) {
        if (categoryBloc.state is CategoryLoaded) {
          categories = (categoryBloc.state as CategoryLoaded).categories;
        }
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: BlocProvider.of<HabitBloc>(context),
          child: HabitDetailDialog(
            habit: habit,
            categories: categories,
          ),
        ),
      ),
    );
  }

  void _navigateToTodoDetail(Todo todo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodoDetailPage(todo: todo),
      ),
    );
  }

  void _navigateToDiaryDetail(Journal diary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DiaryDetailView(diary: diary),
      ),
    );
  }

  void _navigateToProductDetail(StarProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'water_drop': Icons.water_drop,
      'menu_book': Icons.menu_book,
      'directions_run': Icons.directions_run,
      'fitness_center': Icons.fitness_center,
      'self_improvement': Icons.self_improvement,
      'mic': Icons.mic,
      'bedtime': Icons.bedtime,
      'restaurant': Icons.restaurant,
      'local_cafe': Icons.local_cafe,
      'smoke_free': Icons.smoke_free,
      'no_drinks': Icons.no_drinks,
      'phone_android': Icons.phone_android,
      'code': Icons.code,
      'brush': Icons.brush,
      'music_note': Icons.music_note,
      'palette': Icons.palette,
      'school': Icons.school,
      'work': Icons.work,
      'nights_stay': Icons.nights_stay,
      'alarm': Icons.alarm,
      'cleaning_services': Icons.cleaning_services,
      'emoji_events': Icons.emoji_events,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'thumb_up': Icons.thumb_up,
      'mood': Icons.mood,
    };
    return iconMap[iconName] ?? Icons.book;
  }

  Color _getPriorityColor(TodoPriority priority, ThemeData theme) {
    switch (priority) {
      case TodoPriority.high:
        return theme.colorScheme.error;
      case TodoPriority.medium:
        return theme.colorScheme.secondary;
      case TodoPriority.low:
        return theme.colorScheme.tertiary;
    }
  }

  String _getPriorityLabel(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return '高';
      case TodoPriority.medium:
        return '中';
      case TodoPriority.low:
        return '低';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DiaryDetailView extends ConsumerWidget {
  final Journal diary;

  const _DiaryDetailView({required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentThemeProvider);
    final theme = Theme.of(context);
    final textContent = diary.content
        .where((block) => block.type == ContentBlockType.text)
        .map((block) => block.data)
        .join('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(diary.title.isNotEmpty ? diary.title : '日记详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(diary.date),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (textContent.isNotEmpty)
              Text(
                textContent,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            if (diary.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: diary.tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
