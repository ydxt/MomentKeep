import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// 退货物流录入对话框
/// 用户退货申请通过后，在此录入退货快递信息
class ReturnLogisticsDialog extends StatefulWidget {
  const ReturnLogisticsDialog({
    super.key,
    required this.orderId,
    this.onSubmitted,
  });

  final String orderId;
  final VoidCallback? onSubmitted;

  @override
  State<ReturnLogisticsDialog> createState() => _ReturnLogisticsDialogState();
}

class _ReturnLogisticsDialogState extends State<ReturnLogisticsDialog> {
  final _productDb = ProductDatabaseService();
  final _trackingNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<LogisticsCompany> _logisticsCompanies = [];
  LogisticsCompany? _selectedCompany;
  bool _isLoadingCompanies = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLogisticsCompanies();
    _trackingNumberController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _trackingNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadLogisticsCompanies() async {
    try {
      final companies = await _productDb.getAllLogisticsCompanies(isActive: true);
      if (mounted) {
        setState(() {
          _logisticsCompanies = companies;
          _isLoadingCompanies = false;
          if (companies.isNotEmpty) {
            _selectedCompany = companies.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCompanies = false;
          _errorMessage = '加载物流公司失败';
        });
      }
    }
  }

  Future<void> _submitReturnLogistics() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final trackingNumber = _trackingNumberController.text.trim();
      final now = DateTime.now();

      await _productDb.insertReturnLogistics({
        'order_id': widget.orderId,
        'tracking_number': trackingNumber,
        'logistics_company_id': _selectedCompany?.id,
        'status': 'shipped',
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      await _productDb.insertLogisticsTrack(LogisticsTrack(
        orderId: widget.orderId,
        logisticsCompanyId: _selectedCompany?.id,
        trackingNumber: trackingNumber,
        status: 'shipped',
        description: '买家已寄出退货包裹',
        location: '买家地址',
        trackTime: now,
        createdAt: now,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('退货物流信息已提交'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onSubmitted?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '提交失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.assignment_return, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '退货物流信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请填写退货的快递公司和运单号，方便商家跟踪退货进度',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '快递公司',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingCompanies
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _logisticsCompanies.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '暂无可用物流公司',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        )
                      : DropdownButtonFormField<LogisticsCompany>(
                          value: _selectedCompany,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _logisticsCompanies.map((company) {
                            return DropdownMenuItem(
                              value: company,
                              child: Text(company.name),
                            );
                          }).toList(),
                          onChanged: (company) {
                            setState(() {
                              _selectedCompany = company;
                            });
                          },
                        ),
              const SizedBox(height: 20),
              Text(
                '退货运单号',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _trackingNumberController,
                decoration: InputDecoration(
                  hintText: '请输入退货运单号',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _trackingNumberController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: _trackingNumberController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('运单号已复制'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          tooltip: '复制',
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入退货运单号';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReturnLogistics,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('提交'),
        ),
      ],
    );
  }
}