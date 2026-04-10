import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/services/import_export_service.dart';

/// 导入结果页面
class ImportResultPage extends ConsumerStatefulWidget {
  final String filePath;

  const ImportResultPage({
    Key? key,
    required this.filePath,
  }) : super(key: key);

  @override
  ConsumerState<ImportResultPage> createState() => _ImportResultPageState();
}

class _ImportResultPageState extends ConsumerState<ImportResultPage> {
  bool _isImporting = false;
  ImportResult? _result;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    setState(() => _isImporting = true);

    try {
      final service = ImportExportService();
      final importResult = await service.importData(widget.filePath);

      if (mounted) {
        setState(() => _result = importResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = ImportResult(
            success: false,
            errorMessage: '导入失败: $e',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return PopScope(
      canPop: !_isImporting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('导入进度'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !_isImporting,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isImporting
                ? _buildLoadingState(theme)
                : _buildResultState(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(dynamic theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '正在导入数据...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '请勿关闭应用',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildResultState(dynamic theme) {
    if (_result == null) {
      return const SizedBox.shrink();
    }

    if (_result!.success) {
      return _buildSuccessResult(theme);
    } else {
      return _buildFailureResult(theme);
    }
  }

  Widget _buildSuccessResult(dynamic theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 100,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '导入成功！',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '共导入 ${_result!.totalImported} 条数据',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // 详细统计
        Container(
          width: double.infinity,
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
                '导入详情',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (_result!.categoriesImported > 0)
                _buildResultItem('分类', _result!.categoriesImported, theme),
              if (_result!.todosImported > 0)
                _buildResultItem('待办事项', _result!.todosImported, theme),
              if (_result!.habitsImported > 0)
                _buildResultItem('习惯', _result!.habitsImported, theme),
              if (_result!.journalsImported > 0)
                _buildResultItem('日记', _result!.journalsImported, theme),
              if (_result!.pomodorosImported > 0)
                _buildResultItem('番茄钟', _result!.pomodorosImported, theme),
              if (_result!.plansImported > 0)
                _buildResultItem('计划', _result!.plansImported, theme),
              if (_result!.achievementsImported > 0)
                _buildResultItem('成就', _result!.achievementsImported, theme),
              if (_result!.recycleBinImported > 0)
                _buildResultItem('回收站', _result!.recycleBinImported, theme),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 完成按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('完成'),
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
    );
  }

  Widget _buildFailureResult(dynamic theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 100,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(
          '导入失败',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.error.withOpacity(0.5)),
          ),
          child: Text(
            _result!.errorMessage ?? '未知错误',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // 重试和取消按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.cancel),
                label: const Text('取消'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startImport,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
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
      ],
    );
  }

  Widget _buildResultItem(String label, int count, dynamic theme) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count 条',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
