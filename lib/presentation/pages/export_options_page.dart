import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/services/import_export_service.dart';
import 'package:moment_keep/presentation/components/export_module_selector.dart';

class ExportOptionsPage extends ConsumerStatefulWidget {
  const ExportOptionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportOptionsPage> createState() => _ExportOptionsPageState();
}

class _ExportOptionsPageState extends ConsumerState<ExportOptionsPage> {
  bool _isExporting = false;
  double? _progress;
  String _exportFormat = 'zip';

  Map<String, bool> _selectedModules = {
    'categories': true,
    'todos': true,
    'habits': true,
    'journals': true,
    'pomodoros': true,
    'plans': true,
    'achievements': true,
    'recycleBin': true,
    'media': true,
  };

  Map<String, ExportTimeRange> _timeRanges = {};

  Future<void> _handleExport() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _progress = 0;
    });

    try {
      setState(() => _progress = 0.2);

      final service = ImportExportService();
      final todoTimeRange = _timeRanges['todos'];
      final habitTimeRange = _timeRanges['habits'];

      final filePath = await service.exportData(
        exportCategories: _selectedModules['categories'] ?? true,
        exportTodos: _selectedModules['todos'] ?? true,
        exportHabits: _selectedModules['habits'] ?? true,
        exportJournals: _selectedModules['journals'] ?? true,
        exportPomodoros: _selectedModules['pomodoros'] ?? true,
        exportPlans: _selectedModules['plans'] ?? true,
        exportAchievements: _selectedModules['achievements'] ?? true,
        exportRecycleBin: _selectedModules['recycleBin'] ?? true,
        exportMedia: _selectedModules['media'] ?? true,
        format: _exportFormat,
        todoStartDate: todoTimeRange?.startDate,
        todoEndDate: todoTimeRange?.endDate,
        habitStartDate: habitTimeRange?.startDate,
        habitEndDate: habitTimeRange?.endDate,
      );

      setState(() => _progress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功！')),
        );

        await _shareFile(filePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '拾光记数据导出',
        text: '导出时间: ${DateTime.now().toString()}',
      );
    } catch (e) {
      print('分享文件失败: $e');
    }
  }

  String _getFormatDisplayName(String format) {
    switch (format) {
      case 'zip':
        return 'ZIP（结构化 JSON）';
      case 'excel':
        return 'Excel（.xlsx）';
      case 'json':
        return 'JSON（纯数据）';
      default:
        return format;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出数据'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '导出文件包含所有选中模块的结构化数据，支持后续导入恢复。媒体文件会一并打包。',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ExportModuleSelector(
              selectedModules: _selectedModules,
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedModules = newSelection;
                });
              },
              timeRanges: _timeRanges,
              onTimeRangesChanged: (newRanges) {
                setState(() {
                  _timeRanges = newRanges;
                });
              },
            ),
            const SizedBox(height: 24),

            Text(
              '导出格式',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'zip',
                  label: Text('ZIP'),
                  icon: Icon(Icons.folder_zip, size: 18),
                ),
                ButtonSegment<String>(
                  value: 'excel',
                  label: Text('Excel'),
                  icon: Icon(Icons.table_chart, size: 18),
                ),
                ButtonSegment<String>(
                  value: 'json',
                  label: Text('JSON'),
                  icon: Icon(Icons.code, size: 18),
                ),
              ],
              selected: {_exportFormat},
              onSelectionChanged: (selection) {
                setState(() {
                  _exportFormat = selection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getFormatDescription(_exportFormat),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出统计',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatItem(
                    '已选模块',
                    '${_selectedModules.values.where((v) => v).length} / ${_selectedModules.length}',
                    theme,
                  ),
                  _buildStatItem('文件格式', _getFormatDisplayName(_exportFormat), theme),
                  _buildStatItem('包含媒体', _selectedModules['media'] == true ? '是' : '否', theme),
                  if (_timeRanges['todos']?.startDate != null || _timeRanges['todos']?.endDate != null)
                    _buildStatItem(
                      '待办时间范围',
                      _getTimeRangeDisplay(_timeRanges['todos']),
                      theme,
                    ),
                  if (_timeRanges['habits']?.startDate != null || _timeRanges['habits']?.endDate != null)
                    _buildStatItem(
                      '习惯时间范围',
                      _getTimeRangeDisplay(_timeRanges['habits']),
                      theme,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExport,
                icon: _isExporting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _progress,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isExporting ? '导出中...' : '开始导出'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormatDescription(String format) {
    switch (format) {
      case 'zip':
        return 'ZIP 格式：包含结构化 JSON 数据和媒体文件，支持完整导入恢复';
      case 'excel':
        return 'Excel 格式：每个模块一个 Sheet，方便查看和编辑，不支持导入';
      case 'json':
        return 'JSON 格式：纯数据文件打包为 ZIP，适合数据处理和迁移';
      default:
        return '';
    }
  }

  String _getTimeRangeDisplay(ExportTimeRange? range) {
    if (range == null) return '全部';
    final parts = <String>[];
    if (range.startDate != null) {
      parts.add('${range.startDate!.year}-${range.startDate!.month.toString().padLeft(2, '0')}-${range.startDate!.day.toString().padLeft(2, '0')}');
    }
    parts.add('至');
    if (range.endDate != null) {
      parts.add('${range.endDate!.year}-${range.endDate!.month.toString().padLeft(2, '0')}-${range.endDate!.day.toString().padLeft(2, '0')}');
    }
    if (parts.length == 1) return '全部';
    return parts.join(' ');
  }

  Widget _buildStatItem(String label, String value, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
