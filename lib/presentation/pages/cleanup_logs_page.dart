import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// 商品清理日志页面
class CleanupLogsPage extends StatefulWidget {
  const CleanupLogsPage({super.key});

  @override
  State<CleanupLogsPage> createState() => _CleanupLogsPageState();
}

class _CleanupLogsPageState extends State<CleanupLogsPage> {
  /// 商品数据库服务实例
  final ProductDatabaseService _productDb = ProductDatabaseService();
  
  /// 清理日志列表
  List<Map<String, dynamic>> _logs = [];
  
  /// 加载状态
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  /// 加载清理日志
  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final logs = await _productDb.getCleanupLogs(limit: 100);
      setState(() {
        _logs = logs;
      });
    } catch (e) {
      debugPrint('加载清理日志失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('加载日志失败'),
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
        title: const Text('清理日志'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    '暂无清理日志',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final cleanupTime = DateTime.fromMillisecondsSinceEpoch(log['cleanup_time']);
                    final successCount = log['success_count'];
                    final failedCount = log['failed_count'];
                    final totalProducts = log['total_products'];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF1a3525),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          '清理时间: ${cleanupTime.toString()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  '待清理商品: ',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '$totalProducts',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text(
                                  '成功: ',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '$successCount',
                                  style: const TextStyle(color: Color(0xFF13ec5b)),
                                ),
                                const Text(
                                  ' 失败: ',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '$failedCount',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.info, color: Colors.grey),
                          onPressed: () {
                            // 显示清理详情
                            _showCleanupDetails(log);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  /// 显示清理详情
  void _showCleanupDetails(Map<String, dynamic> log) {
    final details = log['details'] as String;
    List<String> detailList = [];
    
    try {
      final List<dynamic> parsedDetails = jsonDecode(details);
      detailList = parsedDetails.map((e) => e as String).toList();
    } catch (e) {
      detailList = [details];
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1a3525),
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // 对话框标题
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A4532))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '清理详情',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // 详情内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: detailList.map((detail) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          detail,
                          style: TextStyle(
                            color: detail.contains('成功') ? const Color(0xFF13ec5b) : 
                                  detail.contains('失败') ? Colors.red : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
