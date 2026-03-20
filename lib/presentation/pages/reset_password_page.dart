import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';

/// 密码重置页面
class ResetPasswordPage extends StatelessWidget {
  /// 构造函数
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: BlocProvider(
              create: (context) => SecurityBloc(),
              child: const ResetPasswordForm(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 密码重置表单
class ResetPasswordForm extends StatefulWidget {
  /// 构造函数
  const ResetPasswordForm({super.key});

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  bool _isLoading = false;
  bool _tokenVerified = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 验证重置令牌
  void _verifyToken() {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入重置令牌'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.read<SecurityBloc>().add(
          VerifyResetToken(
            token: _tokenController.text,
          ),
        );
  }

  /// 提交密码重置
  void _submitReset() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SecurityBloc>().add(
            CompletePasswordReset(
              token: _tokenController.text,
              newPassword: _newPasswordController.text,
            ),
          );
    }
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
        } else if (state is ResetTokenVerified) {
          setState(() {
            _isLoading = false;
            _tokenVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('令牌验证成功'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is PasswordResetCompleted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密码重置成功'),
              backgroundColor: Colors.green,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/login');
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
              '重置密码',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请输入重置令牌和新密码',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 重置令牌输入框
            TextFormField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: '重置令牌',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_tokenVerified,
            ),
            const SizedBox(height: 16),

            // 验证令牌按钮（仅在令牌未验证时显示）
            if (!_tokenVerified)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyToken,
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
                      : const Text('验证令牌'),
                ),
              ),

            if (_tokenVerified) ...[
              const SizedBox(height: 16),
              // 新密码输入框
              TextFormField(
                controller: _newPasswordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: '新密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscure = !_isObscure;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入新密码';
                  }
                  if (value.length < 6) {
                    return '密码长度不能少于6位';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 确认密码输入框
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmObscure,
                decoration: InputDecoration(
                  labelText: '确认新密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmObscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmObscure = !_isConfirmObscure;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请确认新密码';
                  }
                  if (value != _newPasswordController.text) {
                    return '两次输入的密码不一致';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 重置密码按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReset,
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
                      : const Text('重置密码'),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 回到登录页面
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
