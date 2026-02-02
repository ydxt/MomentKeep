import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

class ChangePayPasswordPage extends ConsumerStatefulWidget {
  const ChangePayPasswordPage({super.key});

  @override
  ConsumerState<ChangePayPasswordPage> createState() => _ChangePayPasswordPageState();
}

class _ChangePayPasswordPageState extends ConsumerState<ChangePayPasswordPage> {
  // 表单控制器
  final TextEditingController _oldPayPasswordController = TextEditingController();
  final TextEditingController _newPayPasswordController = TextEditingController();
  final TextEditingController _confirmPayPasswordController = TextEditingController();

  // 加载状态
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isLoadingUser = true;
  bool _hasPayPassword = false;

  // 表单验证状态
  String? _oldPayPasswordError;
  String? _newPayPasswordError;
  String? _confirmPayPasswordError;

  @override
  void initState() {
    super.initState();
    _checkIfHasPayPassword();
  }

  @override
  void dispose() {
    _oldPayPasswordController.dispose();
    _newPayPasswordController.dispose();
    _confirmPayPasswordController.dispose();
    super.dispose();
  }

  // 检查用户是否已经设置了支付密码
  Future<void> _checkIfHasPayPassword() async {
    try {
      // 获取当前用户信息
      final securityState = context.read<SecurityBloc>().state;
      if (securityState is SecurityLoaded) {
        final userId = securityState.userAuth.id;

        // 使用UserDatabaseService获取用户信息
        final userDatabase = UserDatabaseService();
        final userData = await userDatabase.getUserById(userId);

        if (userData != null) {
          // 检查是否有支付密码
          final currentPayPasswordHash = userData['pay_password_hash'] as String?;
          setState(() {
            _hasPayPassword = currentPayPasswordHash != null && currentPayPasswordHash.isNotEmpty;
          });
        }
      }
    } catch (e) {
      print('Error checking pay password: $e');
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
    }
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
        title: Text(
          _hasPayPassword ? '修改支付密码' : '设置支付密码',
          style: TextStyle(color: theme.colorScheme.onBackground),
        ),
        centerTitle: true,
      ),
      body: _isLoadingUser
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 旧支付密码（仅当已设置支付密码时显示）
                  if (_hasPayPassword)
                    Column(
                      children: [
                        _buildPasswordInputField(
                          controller: _oldPayPasswordController,
                          label: '原支付密码',
                          hintText: '请输入原支付密码',
                          errorText: _oldPayPasswordError,
                          onChanged: (value) {
                            if (_oldPayPasswordError != null) {
                              setState(() {
                                _oldPayPasswordError = null;
                              });
                            }
                          },
                          theme: theme,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // 新支付密码
                  _buildPasswordInputField(
                    controller: _newPayPasswordController,
                    label: _hasPayPassword ? '新支付密码' : '支付密码',
                    hintText: '请输入${_hasPayPassword ? '新' : ''}支付密码（6位数字）',
                    errorText: _newPayPasswordError,
                    onChanged: (value) {
                      if (_newPayPasswordError != null) {
                        setState(() {
                          _newPayPasswordError = null;
                        });
                      }
                      // 自动验证确认密码
                      if (_confirmPayPasswordController.text.isNotEmpty) {
                        _validateConfirmPayPassword();
                      }
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  // 密码安全提示
                  Text(
                    '• 支付密码用于保护您的资金安全',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• 请不要使用简单密码（如123456）',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• 请定期更换支付密码',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 确认新支付密码
                  _buildPasswordInputField(
                    controller: _confirmPayPasswordController,
                    label: _hasPayPassword ? '确认新支付密码' : '确认支付密码',
                    hintText: '请再次输入${_hasPayPassword ? '新' : ''}支付密码',
                    errorText: _confirmPayPasswordError,
                    onChanged: (value) {
                      _validateConfirmPayPassword();
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 40),

                  // 确认修改按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePayPassword,
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
                          : Text(
                              _hasPayPassword ? '确认修改' : '确认设置',
                              style: TextStyle(color: theme.colorScheme.onPrimary),
                            ),
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
            keyboardType: TextInputType.number,
            maxLength: 6,
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
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  // 验证确认支付密码
  void _validateConfirmPayPassword() {
    if (_confirmPayPasswordController.text != _newPayPasswordController.text) {
      setState(() {
        _confirmPayPasswordError = '两次输入的密码不一致';
      });
    } else {
      setState(() {
        _confirmPayPasswordError = null;
      });
    }
  }

  // 验证表单
  bool _validateForm() {
    bool isValid = true;

    // 验证旧支付密码（只有在已经设置过支付密码的情况下才需要验证）
    if (_hasPayPassword) {
      if (_oldPayPasswordController.text.isEmpty) {
        setState(() {
          _oldPayPasswordError = '请输入原支付密码';
        });
        isValid = false;
      } else if (_oldPayPasswordController.text.length != 6 || int.tryParse(_oldPayPasswordController.text) == null) {
        setState(() {
          _oldPayPasswordError = '支付密码必须是6位数字';
        });
        isValid = false;
      }
    }

    // 验证新支付密码
    if (_newPayPasswordController.text.isEmpty) {
      setState(() {
        _newPayPasswordError = '请输入${_hasPayPassword ? '新' : ''}支付密码';
      });
      isValid = false;
    } else if (_newPayPasswordController.text.length != 6 || int.tryParse(_newPayPasswordController.text) == null) {
      setState(() {
        _newPayPasswordError = '支付密码必须是6位数字';
      });
      isValid = false;
    }

    // 验证确认支付密码
    if (_confirmPayPasswordController.text.isEmpty) {
      setState(() {
        _confirmPayPasswordError = '请确认${_hasPayPassword ? '新' : ''}支付密码';
      });
      isValid = false;
    } else if (_confirmPayPasswordController.text != _newPayPasswordController.text) {
      setState(() {
        _confirmPayPasswordError = '两次输入的密码不一致';
      });
      isValid = false;
    }

    return isValid;
  }

  // 修改或设置支付密码
  Future<void> _changePayPassword() async {
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

        // 检查是否有支付密码
        final currentPayPasswordHash = userData['pay_password_hash'] as String?;

        // 如果没有设置过支付密码，直接设置新密码
        if (currentPayPasswordHash == null || currentPayPasswordHash.isEmpty) {
          // 生成新支付密码哈希
          final newPayPasswordHash = await EncryptionHelper.encrypt(_newPayPasswordController.text);

          // 更新数据库中的支付密码
          await userDatabase.updateUser(
            userId,
            {},
            {'pay_password_hash': newPayPasswordHash},
          );

          // 显示成功提示
          _showSuccess('支付密码设置成功');
        } else {
          // 验证旧支付密码
          final isPasswordValid = await EncryptionHelper.decrypt(currentPayPasswordHash) == _oldPayPasswordController.text;

          if (!isPasswordValid) {
            setState(() {
              _oldPayPasswordError = '原支付密码错误';
            });
            return;
          }

          // 生成新支付密码哈希
          final newPayPasswordHash = await EncryptionHelper.encrypt(_newPayPasswordController.text);

          // 更新数据库中的支付密码
          await userDatabase.updateUser(
            userId,
            {},
            {'pay_password_hash': newPayPasswordHash},
          );

          // 显示成功提示
          _showSuccess('支付密码修改成功');
        }

        // 返回上一页
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('修改支付密码失败: $e');
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