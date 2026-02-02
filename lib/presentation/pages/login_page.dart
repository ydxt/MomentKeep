import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';

/// 登录页面
class LoginPage extends StatelessWidget {
  /// 构造函数
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: BlocProvider(
              create: (context) => SecurityBloc(),
              child: const LoginForm(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录表单
class LoginForm extends StatefulWidget {
  /// 构造函数
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SecurityBloc, SecurityState>(
      listener: (context, state) {
        if (state is SecurityLoaded) {
          // 登录成功，导航到主页
          Navigator.pushReplacementNamed(context, '/home');
        } else if (state is SecurityError) {
          // 显示错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标和标题
            Image.asset(
              'assets/images/momentkeep.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 16),
            Text(
              '每日打卡',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录您的账号',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
                final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                if (!emailRegex.hasMatch(value)) {
                  return '请输入有效的邮箱地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 密码输入框
            TextFormField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: '密码',
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
                  return '请输入密码';
                }
                if (value.length < 6) {
                  return '密码长度不能少于6位';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // 忘记密码链接
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // 跳转到忘记密码页面
                  Navigator.pushNamed(context, '/forgot_password');
                },
                child: const Text('忘记密码?'),
              ),
            ),
            const SizedBox(height: 24),

            // 登录按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    // 提交登录表单
                    context.read<SecurityBloc>().add(
                          LoginEvent(
                            email: _emailController.text,
                            password: _passwordController.text,
                          ),
                        );
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('登录'),
              ),
            ),
            const SizedBox(height: 16),

            // 注册链接
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('还没有账号?'),
                TextButton(
                  onPressed: () {
                    // 跳转到注册页面
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('立即注册'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 关于按钮
            TextButton(
              onPressed: () {
                _showAboutDialog(context);
              },
              child: const Text('关于'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 显示关于对话框
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AboutDialogWidget(),
    );
  }
}

/// 关于对话框
class AboutDialogWidget extends StatefulWidget {
  const AboutDialogWidget({super.key});
  
  @override
  State<AboutDialogWidget> createState() => _AboutDialogWidgetState();
}

class _AboutDialogWidgetState extends State<AboutDialogWidget> {
  // 连续点击计数
  int _logoTapCount = 0;
  // 点击计时器，重置计数
  Timer? _logoTapTimer;
  
  @override
  void dispose() {
    _logoTapTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 软件logo（可点击）
            GestureDetector(
              onTap: () {
                _handleLogoTap();
              },
              child: Image.asset(
                'assets/images/momentkeep.png',
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 16),
            
            // 软件名称
            Text(
              '每日打卡',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 版本信息
            Text(
              '版本 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            // 版权信息
            const Text(
              '© 2025 每日打卡团队\n保留所有权利',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // 功能描述
            const Text(
              '一款简洁高效的每日打卡应用，帮助您养成良好的习惯，记录美好生活。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // 关闭按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 处理logo点击事件
  void _handleLogoTap() {
    setState(() {
      _logoTapCount++;
    });
    
    // 重置计时器
    _logoTapTimer?.cancel();
    _logoTapTimer = Timer(const Duration(seconds: 1), () {
      _logoTapCount = 0;
    });
    
    // 连续点击5次，显示暗号输入框
    if (_logoTapCount == 5) {
      _showAdminCodeDialog();
    }
  }
  
  /// 显示暗号输入对话框
  void _showAdminCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入暗号'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: '请输入暗号',
          ),
          obscureText: true,
          onSubmitted: (value) {
            _checkAdminCode(value, codeController);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _checkAdminCode(codeController.text, codeController);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 检查管理员暗号
  void _checkAdminCode(String code, TextEditingController controller) {
    if (code == 'admin_reg') {
      // 关闭暗号对话框
      Navigator.pop(context);
      // 显示管理员注册界面
      _showAdminRegisterDialog();
    } else {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暗号错误'),
          backgroundColor: Colors.red,
        ),
      );
    }
    controller.clear();
  }
  
  /// 显示管理员注册对话框
  void _showAdminRegisterDialog() {
    // 管理员注册表单控制器
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  '管理员注册',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 用户名输入
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 邮箱输入
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 密码输入
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 确认密码输入
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '确认密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 注册按钮
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      _registerAdmin(
                        usernameController.text,
                        emailController.text,
                        passwordController.text,
                        confirmPasswordController.text,
                      );
                    },
                    child: const Text('注册管理员'),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 取消按钮
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 注册管理员
  void _registerAdmin(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) {
    // 表单验证
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写所有字段'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('两次密码输入不一致'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 调用SecurityBloc注册管理员
    final securityBloc = BlocProvider.of<SecurityBloc>(context);
    
    // 关闭对话框
    Navigator.pop(context);
    
    // 使用独立的BlocListener监听注册结果
    final listener = BlocListener<SecurityBloc, SecurityState>(
      bloc: securityBloc,
      listener: (context, state) {
        if (state is SecurityLoaded) {
          // 注册成功
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('管理员注册成功'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is SecurityError) {
          // 注册失败
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('注册失败: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: const SizedBox.shrink(),
    );
    
    // 添加到当前上下文
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(builder: (context) => listener);
    overlay.insert(overlayEntry);
    
    // 延迟移除overlay entry
    Future.delayed(const Duration(seconds: 5), () {
      overlayEntry.remove();
    });
    
    // 触发注册事件
    securityBloc.add(
      RegisterEvent(
        username: username,
        email: email,
        password: password,
        isAdmin: true,
      ),
    );
  }
}
