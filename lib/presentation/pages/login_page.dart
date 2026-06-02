import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';

class LoginPage extends StatelessWidget {
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

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isObscure = true;
  List<String> _loginHistory = [];
  bool _showHistory = false;
  bool _isSelectingFromHistory = false;

  static const _loginHistoryKey = StorageKeys.loginAccountHistory;
  static const _maxHistoryCount = 10;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus && _loginHistory.isNotEmpty) {
        setState(() => _showHistory = true);
      }
    });
    _emailController.addListener(() {
      if (_isSelectingFromHistory) return;
      if (_emailFocusNode.hasFocus && _loginHistory.isNotEmpty) {
        setState(() => _showHistory = true);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLoginHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_loginHistoryKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        setState(() {
          _loginHistory = list.cast<String>();
        });
      }
    } catch (e) {
      _loginHistory = [];
    }
  }

  Future<void> _saveLoginHistory(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _loginHistory.remove(email);
      _loginHistory.insert(0, email);
      if (_loginHistory.length > _maxHistoryCount) {
        _loginHistory = _loginHistory.sublist(0, _maxHistoryCount);
      }
      await prefs.setString(_loginHistoryKey, jsonEncode(_loginHistory));
      setState(() {});
    } catch (e) {
      // 静默失败
    }
  }

  void _removeLoginHistory(String email) {
    setState(() {
      _loginHistory.remove(email);
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_loginHistoryKey, jsonEncode(_loginHistory));
    });
  }

  List<String> get _filteredHistory {
    final input = _emailController.text.trim().toLowerCase();
    if (input.isEmpty) return _loginHistory;
    return _loginHistory.where((e) => e.toLowerCase().contains(input)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SecurityBloc, SecurityState>(
      listener: (context, state) {
        if (state is SecurityLoaded) {
          _saveLoginHistory(_emailController.text.trim());
          Navigator.pushReplacementNamed(context, '/home');
        } else if (state is SecurityError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_showHistory) {
            setState(() => _showHistory = false);
          }
        },
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

            _buildEmailField(theme),
            if (_showHistory && _filteredHistory.isNotEmpty)
              _buildHistoryList(theme),
            const SizedBox(height: 16),

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
                return null;
              },
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/forgot_password');
                },
                child: const Text('忘记密码?'),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() => _showHistory = false);
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('还没有账号?'),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('立即注册'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                _showAboutDialog(context);
              },
              child: const Text('关于'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: '邮箱',
        prefixIcon: const Icon(Icons.email_outlined),
        suffixIcon: _emailController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _emailController.clear();
                  setState(() {});
                },
              )
            : (_loginHistory.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () {
                      setState(() => _showHistory = !_showHistory);
                    },
                  )
                : null),
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
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    final filtered = _filteredHistory;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filtered.map((email) => _buildHistoryItem(email, theme)).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String email, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  _selectHistoryAccount(email);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          email,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                _removeLoginHistory(email);
              },
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectHistoryAccount(String email) {
    _isSelectingFromHistory = true;
    _emailController.text = email;
    _isSelectingFromHistory = false;
    _showHistory = false;
    _emailFocusNode.unfocus();
    setState(() {});
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AboutDialogWidget(),
    );
  }
}

class AboutDialogWidget extends StatefulWidget {
  const AboutDialogWidget({super.key});

  @override
  State<AboutDialogWidget> createState() => _AboutDialogWidgetState();
}

class _AboutDialogWidgetState extends State<AboutDialogWidget> {
  int _logoTapCount = 0;
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
            GestureDetector(
              onTap: _handleLogoTap,
              child: Image.asset(
                'assets/images/momentkeep.png',
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '每日打卡',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2025 每日打卡团队\n保留所有权利',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              '一款简洁高效的每日打卡应用，帮助您养成良好的习惯，记录美好生活。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogoTap() {
    setState(() => _logoTapCount++);
    _logoTapTimer?.cancel();
    _logoTapTimer = Timer(const Duration(seconds: 1), () {
      _logoTapCount = 0;
    });
    if (_logoTapCount == 5) {
      _showAdminCodeDialog();
    }
  }

  void _showAdminCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入暗号'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: '请输入暗号'),
          obscureText: true,
          onSubmitted: (value) => _checkAdminCode(value, codeController),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => _checkAdminCode(codeController.text, codeController),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _checkAdminCode(String code, TextEditingController controller) {
    if (code == 'admin_reg') {
      Navigator.pop(context);
      _showAdminRegisterDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暗号错误'), backgroundColor: Colors.red),
      );
    }
    controller.clear();
  }

  void _showAdminRegisterDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('管理员注册',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                      labelText: '用户名', prefixIcon: Icon(Icons.person_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _registerAdmin(
                      usernameController.text,
                      emailController.text,
                      passwordController.text,
                      confirmPasswordController.text,
                    ),
                    child: const Text('注册管理员'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _registerAdmin(String username, String email, String password, String confirmPassword) {
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写所有字段'), backgroundColor: Colors.red),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次密码输入不一致'), backgroundColor: Colors.red),
      );
      return;
    }

    final securityBloc = BlocProvider.of<SecurityBloc>(context);
    Navigator.pop(context);

    final listener = BlocListener<SecurityBloc, SecurityState>(
      bloc: securityBloc,
      listener: (context, state) {
        if (state is SecurityLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('管理员注册成功'), backgroundColor: Colors.green),
          );
        } else if (state is SecurityError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('注册失败: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      child: const SizedBox.shrink(),
    );

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(builder: (context) => listener);
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 5), () => overlayEntry.remove());

    securityBloc.add(RegisterEvent(
      username: username,
      email: email,
      password: password,
      isAdmin: true,
    ));
  }
}
