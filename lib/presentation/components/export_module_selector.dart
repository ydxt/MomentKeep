import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class ExportTimeRange {
  final DateTime? startDate;
  final DateTime? endDate;

  const ExportTimeRange({this.startDate, this.endDate});

  ExportTimeRange copyWith({DateTime? startDate, DateTime? endDate}) {
    return ExportTimeRange(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class ExportModuleSelector extends ConsumerWidget {
  final Map<String, bool> selectedModules;
  final Function(Map<String, bool>) onSelectionChanged;
  final Map<String, ExportTimeRange> timeRanges;
  final Function(Map<String, ExportTimeRange>) onTimeRangesChanged;

  const ExportModuleSelector({
    Key? key,
    required this.selectedModules,
    required this.onSelectionChanged,
    required this.timeRanges,
    required this.onTimeRangesChanged,
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
        'hasTimeRange': false,
      },
      {
        'key': 'todos',
        'title': '待办事项',
        'icon': Icons.checklist,
        'description': '待办事项及子任务',
        'hasTimeRange': true,
      },
      {
        'key': 'habits',
        'title': '习惯追踪',
        'icon': Icons.track_changes,
        'description': '习惯及打卡记录',
        'hasTimeRange': true,
      },
      {
        'key': 'journals',
        'title': '日记',
        'icon': Icons.menu_book,
        'description': '日记内容（含媒体文件）',
        'hasTimeRange': false,
      },
      {
        'key': 'pomodoros',
        'title': '番茄钟',
        'icon': Icons.timer,
        'description': '专注时间记录',
        'hasTimeRange': false,
      },
      {
        'key': 'plans',
        'title': '计划',
        'icon': Icons.calendar_today,
        'description': '学习计划',
        'hasTimeRange': false,
      },
      {
        'key': 'achievements',
        'title': '成就',
        'icon': Icons.emoji_events,
        'description': '成就解锁记录',
        'hasTimeRange': false,
      },
      {
        'key': 'recycleBin',
        'title': '回收站',
        'icon': Icons.delete_sweep,
        'description': '回收站项目',
        'hasTimeRange': false,
      },
      {
        'key': 'media',
        'title': '媒体文件',
        'icon': Icons.image,
        'description': '图片、音频、视频',
        'hasTimeRange': false,
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
          final hasTimeRange = module['hasTimeRange'] as bool;

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
            child: Column(
              children: [
                CheckboxListTile(
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
                if (isSelected && hasTimeRange)
                  _buildTimeRangeSelector(context, theme, key, module['title'] as String),
              ],
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

  Widget _buildTimeRangeSelector(BuildContext context, dynamic theme, String key, String title) {
    final timeRange = timeRanges[key] ?? const ExportTimeRange();
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '时间范围（可选）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (timeRange.startDate != null || timeRange.endDate != null)
                  GestureDetector(
                    onTap: () {
                      final newRanges = Map<String, ExportTimeRange>.from(timeRanges);
                      newRanges[key] = const ExportTimeRange();
                      onTimeRangesChanged(newRanges);
                    },
                    child: Text(
                      '清除',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    context: context,
                    theme: theme,
                    label: '开始日期',
                    date: timeRange.startDate,
                    dateFormat: dateFormat,
                    onDateSelected: (date) {
                      final newRanges = Map<String, ExportTimeRange>.from(timeRanges);
                      newRanges[key] = timeRange.copyWith(startDate: date);
                      onTimeRangesChanged(newRanges);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '至',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDateButton(
                    context: context,
                    theme: theme,
                    label: '结束日期',
                    date: timeRange.endDate,
                    dateFormat: dateFormat,
                    onDateSelected: (date) {
                      final newRanges = Map<String, ExportTimeRange>.from(timeRanges);
                      newRanges[key] = timeRange.copyWith(endDate: date);
                      onTimeRangesChanged(newRanges);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required BuildContext context,
    required dynamic theme,
    required String label,
    required DateTime? date,
    required DateFormat dateFormat,
    required Function(DateTime) onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                date != null ? dateFormat.format(date) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: date != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
