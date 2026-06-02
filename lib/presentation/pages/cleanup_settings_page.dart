import 'package:flutter/material.dart';
import 'package:moment_keep/core/services/auto_cleanup_service.dart';

/// 商品清理设置页面
class CleanupSettingsPage extends StatefulWidget {
  const CleanupSettingsPage({super.key});

  @override
  State<CleanupSettingsPage> createState() => _CleanupSettingsPageState();
}

class _CleanupSettingsPageState extends State<CleanupSettingsPage> {
  /// 自动清理服务实例
  final AutoCleanupService _cleanupService = AutoCleanupService();
  
  /// 清理天数
  int _cleanupDays = 30;
  
  /// 加载状态
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载清理设置
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final days = await _cleanupService.getCleanupDays();
      setState(() {
        _cleanupDays = days;
      });
    } catch (e) {
      debugPrint('加载清理设置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('加载设置失败'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存清理设置
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _cleanupService.setCleanupDays(_cleanupDays);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置保存成功'),
          backgroundColor: Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('保存清理设置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存设置失败'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102216),
        foregroundColor: Colors.white,
        title: const Text('清理设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 清理天数设置
                  const Text(
                    '商品清理天数',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '设置商品标记为删除后，自动清理的天数。超过设置天数的删除商品将被永久删除。',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 滑块设置
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '$_cleanupDays 天',
                          style: const TextStyle(
                            color: Color(0xFF13ec5b),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _cleanupDays.toDouble(),
                          min: 7,
                          max: 90,
                          divisions: 12,
                          label: '$_cleanupDays 天',
                          activeColor: const Color(0xFF13ec5b),
                          inactiveColor: const Color(0xFF1a3525),
                          onChanged: (value) {
                            setState(() {
                              _cleanupDays = value.toInt();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('保存设置'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
