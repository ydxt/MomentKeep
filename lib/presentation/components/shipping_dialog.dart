import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';

/// 发货对话框
/// 根据商品类型自动切换实物物流/虚拟商品两种发货模式
class ShippingDialog extends StatefulWidget {
  const ShippingDialog({
    super.key,
    required this.orderId,
    required this.productName,
    required this.isElectronic,
    this.onShipSuccess,
  });

  final String orderId;
  final String productName;
  final bool isElectronic;
  final VoidCallback? onShipSuccess;

  @override
  State<ShippingDialog> createState() => _ShippingDialogState();
}

class _ShippingDialogState extends State<ShippingDialog> {
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

  /// 加载所有启用的物流公司列表
  /// 刷新时会保留之前选中的公司（通过 id 匹配）
  Future<void> _loadLogisticsCompanies() async {
    try {
      final companies = await _productDb.getAllLogisticsCompanies(isActive: true);
      if (mounted) {
        setState(() {
          _logisticsCompanies = companies;
          _isLoadingCompanies = false;
          _errorMessage = null;
          if (companies.isNotEmpty) {
            final previousId = _selectedCompany?.id;
            if (previousId != null) {
              _selectedCompany = companies.cast<LogisticsCompany?>().firstWhere(
                (c) => c?.id == previousId,
                orElse: () => companies.first,
              );
            } else {
              _selectedCompany = companies.first;
            }
          } else {
            _selectedCompany = null;
          }
        });
      }
    } catch (e) {
      debugPrint('加载物流公司失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingCompanies = false;
          _errorMessage = '加载物流公司失败';
          // 不清除 _logisticsCompanies，保留已有数据以便用户继续操作
        });
      }
    }
  }

  /// 弹出添加物流公司对话框，成功后刷新列表
  Future<void> _showAddCompanyDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: dialogTheme.colorScheme.surface,
          title: Text(
            '添加物流公司',
            style: TextStyle(
              color: dialogTheme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '公司名称 *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: '公司编码 *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '客服电话（选填）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: websiteController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: '官网地址（选填）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                '取消',
                style: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('公司名称和编码不能为空'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                try {
                  final newCompany = LogisticsCompany(
                    name: name,
                    code: code,
                    phone: phoneController.text.trim().isNotEmpty
                        ? phoneController.text.trim()
                        : null,
                    website: websiteController.text.trim().isNotEmpty
                        ? websiteController.text.trim()
                        : null,
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await _productDb.insertLogisticsCompany(newCompany);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('添加失败: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: const Text('确认添加'),
            ),
          ],
        );
      },
    );

    if (added == true) {
      await _loadLogisticsCompanies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('物流公司添加成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _submitShipment() async {
    if (widget.isElectronic) {
      await _shipElectronicGoods();
    } else {
      if (!_formKey.currentState!.validate()) return;
      await _shipPhysicalGoods();
    }
  }

  /// 实物商品发货——仅插入首条"商家已发货"轨迹，后续由实际物流进度触发
  Future<void> _shipPhysicalGoods() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final trackingNumber = _trackingNumberController.text.trim();
      final now = DateTime.now();
      final companyId = _selectedCompany?.id;
      final companyName = _selectedCompany?.name ?? '';
      debugPrint('=== ShippingDialog: 开始发货 ===');
      debugPrint('ShippingDialog: orderId=${widget.orderId}');
      debugPrint('ShippingDialog: trackingNumber="$trackingNumber"');
      debugPrint('ShippingDialog: companyId=$companyId, companyName="$companyName"');
      debugPrint('ShippingDialog: isElectronic=false, mounted=$mounted');

      // 仅插入首条发货轨迹，不再一次性模拟后续节点
      await _productDb.insertLogisticsTrack(LogisticsTrack(
        orderId: widget.orderId,
        logisticsCompanyId: companyId,
        trackingNumber: trackingNumber,
        status: 'created',
        description: '商家已发货，等待快递揽收',
        location: '发货地',
        trackTime: now,
        createdAt: now,
      ));
      debugPrint('ShippingDialog: insertLogisticsTrack 调用完成');

      // 更新订单物流信息
      final logisticsData = {
        'tracking_number': trackingNumber,
        'logistics_company': companyName,
        'logistics_status': '已发货',
        'tracks': [
          {'time': _formatTime(now), 'location': '发货地', 'description': '商家已发货，等待快递揽收'},
        ],
      };
      final logisticsInfoJson = jsonEncode(logisticsData);
      debugPrint('ShippingDialog: logistics_info JSON=$logisticsInfoJson');

      final updateResult = await _productDb.updateOrder(widget.orderId, {
        'status': '已发货',
        'logistics_info': logisticsInfoJson,
        'logistics_company_id': companyId,
      });
      debugPrint('ShippingDialog: updateOrder返回=$updateResult (0=未更新任何行, 1=更新成功)');

      if (mounted) {
        debugPrint('ShippingDialog: 显示成功提示，调用onShipSuccess，准备pop');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发货成功！物流信息已更新'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onShipSuccess?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('ShippingDialog: 发货异常捕获: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '发货失败: $e';
        });
      }
    }
  }

  /// 虚拟商品发货
  Future<void> _shipElectronicGoods() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();

      await _productDb.updateOrder(widget.orderId, {
        'status': '已完成',
        'logistics_info': jsonEncode({
          'logistics_status': '无需物流',
          'tracks': [
            {'time': _formatTime(now), 'location': '', 'description': '虚拟商品已发放，无需物流配送'},
          ],
        }),
      });

      // 插入一条无物流轨迹记录
      await _productDb.insertLogisticsTrack(LogisticsTrack(
        orderId: widget.orderId,
        status: 'delivered',
        description: '虚拟商品已发放成功，权益即刻生效',
        location: '云端',
        trackTime: now,
        createdAt: now,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('虚拟商品发放成功！订单已完成'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onShipSuccess?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('虚拟商品发货失败: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = '发货失败: $e';
        });
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            widget.isElectronic ? Icons.cloud_done : Icons.local_shipping,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isElectronic ? '虚拟商品发放' : '发货确认',
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
        child: widget.isElectronic ? _buildElectronicContent(theme) : _buildPhysicalContent(theme),
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
          onPressed: (_isSubmitting || _isLoadingCompanies) ? null : _submitShipment,
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
              : Text(widget.isElectronic ? '确认已发放' : '确认发货'),
        ),
      ],
    );
  }

  Widget _buildElectronicContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '该商品为虚拟商品，无需物流配送。点击确认后，系统将自动完成订单。',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '商品名称：${widget.productName}',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '发放方式：无需物流配送',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPhysicalContent(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '商品名称：${widget.productName}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '选择物流公司',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: theme.colorScheme.primary),
                onPressed: _isLoadingCompanies ? null : _loadLogisticsCompanies,
                tooltip: '刷新列表',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, size: 20, color: theme.colorScheme.primary),
                onPressed: _isLoadingCompanies ? null : _showAddCompanyDialog,
                tooltip: '添加物流公司',
                visualDensity: VisualDensity.compact,
              ),
            ],
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '暂无可用物流公司，请先添加物流公司',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showAddCompanyDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('添加物流公司'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade700,
                                side: BorderSide(color: Colors.orange.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<LogisticsCompany>(
                      value: _selectedCompany,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _logisticsCompanies.map((company) {
                        return DropdownMenuItem(
                          value: company,
                          child: Text(
                            company.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (company) {
                        if (company != null) {
                          setState(() {
                            _selectedCompany = company;
                          });
                        }
                      },
                    ),
          const SizedBox(height: 20),
          Text(
            '快递单号',
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
              hintText: '请输入或粘贴快递单号',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        _trackingNumberController.text = data.text!;
                      }
                    },
                    tooltip: '粘贴',
                  ),
                  if (_trackingNumberController.text.isNotEmpty)
                    IconButton(
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
                    ),
                ],
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入快递单号';
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
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}