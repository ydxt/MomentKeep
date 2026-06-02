import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';

class RealNameAuthPage extends ConsumerStatefulWidget {
  final String? userId;
  const RealNameAuthPage({super.key, this.userId});

  @override
  ConsumerState<RealNameAuthPage> createState() => _RealNameAuthPageState();
}

class _RealNameAuthPageState extends ConsumerState<RealNameAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  String _authStatus = 'unverified';
  String? _rejectReason;
  bool _isLoading = true;
  int? _authRecordId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAuthStatus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idCardController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthStatus() async {
    try {
      final userId = widget.userId ?? await DatabaseService().getCurrentUserId() ?? 'default_user';
      final productDb = ProductDatabaseService();
      final authRecord = await productDb.getRealNameAuthByUserId(userId);
      if (authRecord != null && mounted) {
        setState(() {
          _authStatus = authRecord['status'] as String? ?? 'pending';
          _rejectReason = authRecord['reject_reason'] as String?;
          _authRecordId = authRecord['id'] as int?;
          _nameController.text = authRecord['real_name'] as String? ?? '';
          _idCardController.text = _maskIdCard(authRecord['id_card'] as String? ?? '');
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载认证状态失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _maskIdCard(String idCard) {
    if (idCard.length >= 14) {
      return '${idCard.substring(0, 6)}********${idCard.substring(14)}';
    }
    return idCard;
  }

  void _submitAuth() async {
    if (_formKey.currentState!.validate()) {
      try {
        final userId = widget.userId ?? await DatabaseService().getCurrentUserId() ?? 'default_user';
        final productDb = ProductDatabaseService();
        await productDb.insertRealNameAuth({
          'user_id': userId,
          'real_name': _nameController.text.trim(),
          'id_card': _idCardController.text.trim(),
          'status': 'pending',
        });
        if (mounted) {
          setState(() {
            _authStatus = 'pending';
            _rejectReason = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('认证信息已提交，请等待审核'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('提交失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('实名认证'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(theme),
                  if (_rejectReason != null) ...[
                    const SizedBox(height: 12),
                    _buildRejectReasonCard(theme),
                  ],
                  const SizedBox(height: 24),
                  _buildAuthForm(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildRejectReasonCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('驳回原因', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_rejectReason!, style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_authStatus) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = '审核中';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'verified':
        statusColor = Colors.green;
        statusText = '已认证';
        statusIcon = Icons.verified;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = '认证失败';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = theme.colorScheme.primary;
        statusText = '未认证';
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前状态',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm(ThemeData theme) {
    final isVerified = _authStatus == 'verified';
    final isPending = _authStatus == 'pending';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVerified ? '认证信息' : '填写认证信息',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            enabled: !isVerified && !isPending,
            decoration: InputDecoration(
              labelText: '真实姓名',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入真实姓名';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idCardController,
            enabled: !isVerified && !isPending,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: '身份证号码',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入身份证号码';
              }
              final cleanValue = value.replaceAll('*', '');
              if (cleanValue.length != 18 && value.length != 18) {
                return '身份证号码格式不正确';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (!isVerified && !isPending)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitAuth,
                child: Text(_authStatus == 'rejected' ? '重新提交认证' : '提交认证'),
              ),
            ),
          if (isPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                  const SizedBox(width: 12),
                  Text('认证信息审核中，请耐心等待', style: TextStyle(color: Colors.orange, fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
