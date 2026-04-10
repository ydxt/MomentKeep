import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 导出模块选择器组件
class ExportModuleSelector extends ConsumerWidget {
  /// 已选择的模块
  final Map<String, bool> selectedModules;

  /// 选择变化回调
  final Function(Map<String, bool>) onSelectionChanged;

  const ExportModuleSelector({
    Key? key,
    required this.selectedModules,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    final modules = [
      {
        'key': 'categories',
        'title': '分类',
        'icon': Icons.category,
        'description': '所有分类数据',
      },
      {
        'key': 'todos',
        'title': '待办事项',
        'icon': Icons.checklist,
        'description': '待办事项及子任务',
      },
      {
        'key': 'habits',
        'title': '习惯追踪',
        'icon': Icons.track_changes,
        'description': '习惯及打卡记录',
      },
      {
        'key': 'journals',
        'title': '日记',
        'icon': Icons.menu_book,
        'description': '日记内容（含媒体文件）',
      },
      {
        'key': 'pomodoros',
        'title': '番茄钟',
        'icon': Icons.timer,
        'description': '专注时间记录',
      },
      {
        'key': 'plans',
        'title': '计划',
        'icon': Icons.calendar_today,
        'description': '学习计划',
      },
      {
        'key': 'achievements',
        'title': '成就',
        'icon': Icons.emoji_events,
        'description': '成就解锁记录',
      },
      {
        'key': 'recycleBin',
        'title': '回收站',
        'icon': Icons.delete_sweep,
        'description': '回收站项目',
      },
      {
        'key': 'media',
        'title': '媒体文件',
        'icon': Icons.image,
        'description': '图片、音频、视频',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择导出模块',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...modules.map((module) {
          final key = module['key'] as String;
          final isSelected = selectedModules[key] ?? true;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                final newSelection = Map<String, bool>.from(selectedModules);
                newSelection[key] = value ?? false;
                onSelectionChanged(newSelection);
              },
              title: Row(
                children: [
                  Icon(
                    module['icon'] as IconData,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module['title'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          module['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              secondary: Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              activeColor: theme.colorScheme.primary,
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final allSelected = {
                    for (var key in selectedModules.keys) key: true,
                  };
                  onSelectionChanged(allSelected);
                },
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('全选'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final allDeselected = {
                    for (var key in selectedModules.keys) key: false,
                  };
                  onSelectionChanged(allDeselected);
                },
                icon: const Icon(Icons.deselect, size: 18),
                label: const Text('取消全选'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
