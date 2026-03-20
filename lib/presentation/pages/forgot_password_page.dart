import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';

/// 忘记密码页面
class ForgotPasswordPage extends StatelessWidget {
  /// 构造函数
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: BlocProvider(
              create: (context) => SecurityBloc(),
              child: const ForgotPasswordForm(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 忘记密码表单
class ForgotPasswordForm extends StatefulWidget {
  /// 构造函数
  const ForgotPasswordForm({super.key});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// 复制令牌到剪贴板
  Future<void> _copyTokenToClipboard() async {
    if (_resetToken != null) {
      await Clipboard.setData(ClipboardData(text: _resetToken!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('令牌已复制到剪贴板'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 跳转到密码重置页面
  void _goToResetPassword() {
    Navigator.pushNamed(context, '/reset_password');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SecurityBloc, SecurityState>(
      listener: (context, state) {
        if (state is SecurityLoading) {
          setState(() {
            _isLoading = true;
          });
        } else if (state is PasswordResetRequested) {
          setState(() {
            _isLoading = false;
            _resetToken = state.token;
          });
        } else if (state is SecurityError) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标
            Image.asset(
              'assets/images/momentkeep.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              '忘记密码',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _resetToken == null
                  ? '请输入您的邮箱，我们将生成密码重置令牌'
                  : '密码重置令牌已生成',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 邮箱输入框（仅在未生成令牌时显示）
            if (_resetToken == null) ...[
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入邮箱';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return '请输入有效的邮箱地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            context.read<SecurityBloc>().add(
                                  RequestPasswordReset(
                                    email: _emailController.text,
                                  ),
                                );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('生成重置令牌'),
                ),
              ),
            ],

            // 令牌显示区域（生成令牌后显示）
            if (_resetToken != null) ...[
              // 令牌卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '重置令牌',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _resetToken!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _copyTokenToClipboard,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('复制令牌'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 去重置密码按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _goToResetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('去重置密码'),
                ),
              ),
              const SizedBox(height: 16),

              // 重新生成令牌按钮
              TextButton(
                onPressed: () {
                  setState(() {
                    _resetToken = null;
                  });
                },
                child: const Text('重新生成令牌'),
              ),
            ],

            // 回到登录页面
            if (_resetToken == null)
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('回到登录'),
              ),
          ],
        ),
      ),
    );
  }
}
