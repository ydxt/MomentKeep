import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';

class InvoiceManagementPage extends ConsumerStatefulWidget {
  final String userId;

  const InvoiceManagementPage({super.key, required this.userId});

  @override
  ConsumerState<InvoiceManagementPage> createState() =>
      _InvoiceManagementPageState();
}

class _InvoiceManagementPageState extends ConsumerState<InvoiceManagementPage> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final productDb = ProductDatabaseService();
      final invoices = await productDb.getInvoicesByUserId(widget.userId);
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载发票数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showApplyInvoiceDialog() {
    final theme = ref.read(currentThemeProvider);
    final selectedOrders = <String>{};
    String invoiceType = '个人';
    final titleController = TextEditingController();
    final taxIdController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          title: Text(
            '申请开票',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择订单',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: ProductDatabaseService().getInvoicableOrders(widget.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      final orders = snapshot.data ?? [];
                      if (orders.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('暂无可开票订单', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        );
                      }
                      return Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final orderId = order['id'] as String;
                            final amount = (order['cash_amount'] as num?)?.toDouble() ?? 0;
                            final isSelected = selectedOrders.contains(orderId);
                            return CheckboxListTile(
                              title: Text(
                                '$orderId - ¥${amount.toStringAsFixed(2)}',
                                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                              ),
                              value: isSelected,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedOrders.add(orderId);
                                  } else {
                                    selectedOrders.remove(orderId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  Text(
                    '发票类型',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('个人'),
                          selected: invoiceType == '个人',
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (value) {
                            setDialogState(() {
                              invoiceType = '个人';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('企业'),
                          selected: invoiceType == '企业',
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (value) {
                            setDialogState(() {
                              invoiceType = '企业';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: invoiceType == '个人' ? '发票抬头' : '企业名称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                  if (invoiceType == '企业') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: taxIdController,
                      decoration: InputDecoration(
                        labelText: '纳税人识别号',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '接收邮箱',
                      hintText: '用于接收电子发票',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: selectedOrders.isEmpty || titleController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      try {
                        final productDb = ProductDatabaseService();
                        final now = DateTime.now();
                        final invoiceNo = 'INV${now.millisecondsSinceEpoch}';
                        for (final orderId in selectedOrders) {
                          final orderResult = await productDb.getOrdersByUserId(widget.userId);
                          final order = orderResult.firstWhere(
                            (o) => o['id'] == orderId,
                            orElse: () => <String, dynamic>{},
                          );
                          final amount = (order['cash_amount'] as num?)?.toDouble() ?? 0;
                          await productDb.insertInvoice({
                            'invoice_no': invoiceNo,
                            'order_id': orderId,
                            'user_id': widget.userId,
                            'amount': amount,
                            'invoice_type': invoiceType,
                            'title': titleController.text.trim(),
                            'tax_id': invoiceType == '企业' ? taxIdController.text.trim() : null,
                            'email': emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                            'status': '待开具',
                          });
                        }
                        await _loadInvoices();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('发票申请已提交，共 ${selectedOrders.length} 张'),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('申请失败: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('提交申请'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '待开具':
        return Colors.orange;
      case '已开具':
        return Colors.blue;
      case '已邮寄':
        return Colors.green;
      case '已取消':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '待开具':
        return Icons.pending;
      case '已开具':
        return Icons.check_circle;
      case '已邮寄':
        return Icons.local_shipping;
      case '已取消':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        title: Text(
          '发票管理',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadInvoices,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无发票记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    invoice['invoice_no'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        _getStatusIcon(invoice['status'] ?? ''),
                                        size: 16,
                                        color: _getStatusColor(invoice['status'] ?? ''),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        invoice['status'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _getStatusColor(invoice['status'] ?? ''),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '订单号: ${invoice['order_id']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '¥${((invoice['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${invoice['invoice_type']} - ${invoice['title']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(invoice['created_at'] as int?),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (invoice['tax_id'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '税号: ${invoice['tax_id']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (invoice['email'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '邮箱: ${invoice['email']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyInvoiceDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('申请开票'),
      ),
    );
  }
}
