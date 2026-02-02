import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
        } else if (state is SecurityLoaded) {
          setState(() {
            _isLoading = false;
          });
          // 密码重置成功，显示提示并返回登录页面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密码重置链接已发送到您的邮箱'),
              backgroundColor: Colors.green,
            ),
          );
          // 延迟返回登录页面
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushNamed(context, '/login');
          });
        } else if (state is SecurityError) {
          setState(() {
            _isLoading = false;
          });
          // 显示错误信息
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
              '请输入您的邮箱，我们将发送密码重置链接',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 邮箱输入框
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
                          // 模拟发送密码重置链接
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('密码重置链接已发送到您的邮箱'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // 延迟返回登录页面
                          Future.delayed(const Duration(seconds: 2), () {
                            Navigator.pushNamed(context, '/login');
                          });
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('发送重置链接'),
              ),
            ),
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
