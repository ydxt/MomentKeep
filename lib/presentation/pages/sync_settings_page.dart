import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/core/config/supabase_config.dart';
import 'package:moment_keep/core/services/supabase_service.dart';
import 'package:moment_keep/core/services/supabase_sync_manager.dart';

/// 同步设置页面
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final SupabaseConfig _config = SupabaseConfig();
  final SupabaseService _supabase = SupabaseService();
  final SupabaseSyncManager _syncManager = SupabaseSyncManager();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  bool _isLoading = false;
  bool _isTesting = false;
  bool _testResult = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _urlController.text = _config.supabaseUrl;
    _keyController.text = _config.supabaseAnonKey;
    setState(() {});
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);

    try {
      await _config.setSupabaseUrl(_urlController.text.trim());
      await _config.setSupabaseAnonKey(_keyController.text.trim());

      // 重新初始化 Supabase
      if (_config.isConfigured) {
        await _supabase.dispose();
        await _supabase.initialize();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置保存成功')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('配置保存失败: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = false;
      _testMessage = null;
    });

    try {
      // 先保存配置
      await _saveConfig();

      // 测试连接
      final success = await _supabase.testConnection();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = success;
          _testMessage = success ? '连接成功！' : '连接失败，请检查配置';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = false;
          _testMessage = '连接失败: $e';
        });
      }
    }
  }

  Future<void> _toggleSync(bool enabled) async {
    await _config.setSyncEnabled(enabled);

    if (enabled && _config.isConfigured) {
      await _syncManager.initialize();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleRealtime(bool enabled) async {
    await _config.setRealtimeEnabled(enabled);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _manualSync() async {
    if (!_config.syncEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先启用同步功能')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _syncManager.incrementalSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '同步成功' : '同步失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明卡片
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
                    Icons.cloud_sync,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '配置 Supabase 以实现多设备实时同步。所有数据将加密并安全同步到您的 Supabase 项目。',
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

            // Supabase 配置
            _buildSectionTitle('Supabase 配置', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Supabase URL',
                      hintText: 'https://your-project.supabase.co',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    decoration: InputDecoration(
                      labelText: 'Anon Key',
                      hintText: 'eyJhbGc...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.key),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi, size: 18),
                          label: Text(_isTesting ? '测试中...' : '测试连接'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveConfig,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: const Text('保存配置'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_testMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult
                            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                            : theme.colorScheme.errorContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testResult ? Icons.check_circle : Icons.error,
                            color: _testResult
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: TextStyle(
                                fontSize: 14,
                                color: _testResult
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 同步选项
            _buildSectionTitle('同步选项', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('启用同步'),
                    subtitle: const Text('开启后自动同步所有数据到 Supabase'),
                    value: _config.syncEnabled,
                    onChanged: _toggleSync,
                    secondary: Icon(
                      Icons.sync,
                      color: _config.syncEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('实时同步'),
                    subtitle: const Text('使用 WebSocket 实时推送数据变更'),
                    value: _config.realtimeEnabled,
                    onChanged: _config.syncEnabled ? _toggleRealtime : null,
                    secondary: Icon(
                      Icons.wifi_tethering,
                      color: _config.realtimeEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 同步状态
            _buildSectionTitle('同步状态', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _buildStatusItem(
                    Icons.cloud_done,
                    '配置状态',
                    _config.isConfigured ? '已配置' : '未配置',
                    theme,
                  ),
                  _buildStatusItem(
                    Icons.sync,
                    '同步开关',
                    _config.syncEnabled ? '已开启' : '已关闭',
                    theme,
                  ),
                  _buildStatusItem(
                    Icons.wifi_tethering,
                    '实时同步',
                    _config.realtimeEnabled ? '已开启' : '已关闭',
                    theme,
                  ),
                  _buildStatusItem(
                    Icons.schedule,
                    '最后同步',
                    _config.lastSyncAt?.toString() ?? '从未同步',
                    theme,
                  ),
                  _buildStatusItem(
                    Icons.info,
                    '当前状态',
                    _config.syncStatus,
                    theme,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _config.syncEnabled ? _manualSync : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('立即同步'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 调试信息
            _buildSectionTitle('调试信息', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _config.getDebugInfo().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${entry.key}:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, dynamic theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }
}
