import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  // 表单控制器
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // 加载状态
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // 表单验证状态
  String? _oldPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        foregroundColor: theme.colorScheme.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onBackground),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('修改登录密码', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 旧密码
            _buildPasswordInputField(
              controller: _oldPasswordController,
              label: '旧密码',
              hintText: '请输入旧密码',
              errorText: _oldPasswordError,
              onChanged: (value) {
                if (_oldPasswordError != null) {
                  setState(() {
                    _oldPasswordError = null;
                  });
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 24),

            // 新密码
            _buildPasswordInputField(
              controller: _newPasswordController,
              label: '新密码',
              hintText: '请输入新密码（8-20位）',
              errorText: _newPasswordError,
              onChanged: (value) {
                if (_newPasswordError != null) {
                  setState(() {
                    _newPasswordError = null;
                  });
                }
                // 自动验证确认密码
                if (_confirmPasswordController.text.isNotEmpty) {
                  _validateConfirmPassword();
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 24),

            // 确认新密码
            _buildPasswordInputField(
              controller: _confirmPasswordController,
              label: '确认新密码',
              hintText: '请再次输入新密码',
              errorText: _confirmPasswordError,
              onChanged: (value) {
                _validateConfirmPassword();
              },
              theme: theme,
            ),
            const SizedBox(height: 40),

            // 确认修改按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
                    : Text('确认修改', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建密码输入字段
  Widget _buildPasswordInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? errorText,
    required ValueChanged<String> onChanged,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: !_isPasswordVisible,
            onChanged: onChanged,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              errorText: errorText,
              errorStyle: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  // 验证确认密码
  void _validateConfirmPassword() {
    if (_confirmPasswordController.text != _newPasswordController.text) {
      setState(() {
        _confirmPasswordError = '两次输入的密码不一致';
      });
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }
  }

  // 验证表单
  bool _validateForm() {
    bool isValid = true;

    // 验证旧密码
    if (_oldPasswordController.text.isEmpty) {
      setState(() {
        _oldPasswordError = '请输入旧密码';
      });
      isValid = false;
    }

    // 验证新密码
    if (_newPasswordController.text.isEmpty) {
      setState(() {
        _newPasswordError = '请输入新密码';
      });
      isValid = false;
    } else if (_newPasswordController.text.length < 8 || _newPasswordController.text.length > 20) {
      setState(() {
        _newPasswordError = '密码长度必须在8-20位之间';
      });
      isValid = false;
    }

    // 验证确认密码
    if (_confirmPasswordController.text.isEmpty) {
      setState(() {
        _confirmPasswordError = '请确认新密码';
      });
      isValid = false;
    } else if (_confirmPasswordController.text != _newPasswordController.text) {
      setState(() {
        _confirmPasswordError = '两次输入的密码不一致';
      });
      isValid = false;
    }

    return isValid;
  }

  // 修改密码
  Future<void> _changePassword() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户信息
      final securityState = context.read<SecurityBloc>().state;
      if (securityState is SecurityLoaded) {
        final userId = securityState.userAuth.id;

        // 使用UserDatabaseService获取用户信息
        final userDatabase = UserDatabaseService();
        final userData = await userDatabase.getUserById(userId);

        if (userData == null) {
          _showError('用户不存在');
          return;
        }

        final currentPasswordHash = userData['password_hash'] as String;

        // 验证旧密码
        final isPasswordValid = await EncryptionHelper.decrypt(currentPasswordHash) == _oldPasswordController.text;

        if (!isPasswordValid) {
          setState(() {
            _oldPasswordError = '旧密码错误';
          });
          return;
        }

        // 生成新密码哈希
        final newPasswordHash = await EncryptionHelper.encrypt(_newPasswordController.text);

        // 更新数据库中的密码
        await userDatabase.updateUser(
          userId,
          {},
          {'password_hash': newPasswordHash},
        );

        // 显示成功提示
        _showSuccess('密码修改成功');

        // 返回上一页
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('修改密码失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 显示成功提示
  void _showSuccess(String message) {
    final theme = ref.watch(currentThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 显示错误提示
  void _showError(String message) {
    final theme = ref.watch(currentThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.colorScheme.onError)),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}