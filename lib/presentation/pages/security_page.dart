import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 安全设置页面
class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});

  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  @override
  void initState() {
    super.initState();
    // 加载安全设置
    context.read<SecurityBloc>().add(LoadSecuritySettings());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('安全设置'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: BlocBuilder<SecurityBloc, SecurityState>(
        builder: (context, state) {
          if (state is SecurityLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SecurityError) {
            return Center(child: Text(state.message));
          } else if (state is SecurityLoaded) {
            return _buildSecuritySettings(state, theme);
          } else if (state is BiometricVerifying) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在验证生物识别...'),
                ],
              ),
            );
          } else if (state is BiometricVerified) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text('生物识别验证成功！'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SecurityBloc>().add(LoadSecuritySettings());
                    },
                    child: const Text('返回设置'),
                  ),
                ],
              ),
            );
          } else if (state is BiometricVerificationFailed) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SecurityBloc>().add(LoadSecuritySettings());
                    },
                    child: const Text('返回设置'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  /// 构建安全设置内容
  Widget _buildSecuritySettings(SecurityLoaded state, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息卡片
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用户信息',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('用户名'),
                    subtitle: Text(state.userAuth.username),
                    dense: true,
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('邮箱'),
                    subtitle: Text(state.userAuth.email),
                    dense: true,
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: const Text('上次登录'),
                    subtitle: Text(
                      '${state.userAuth.lastLoginAt.year}-${state.userAuth.lastLoginAt.month.toString().padLeft(2, '0')}-${state.userAuth.lastLoginAt.day.toString().padLeft(2, '0')} ${state.userAuth.lastLoginAt.hour.toString().padLeft(2, '0')}:${state.userAuth.lastLoginAt.minute.toString().padLeft(2, '0')}',
                    ),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 生物识别设置卡片
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '生物识别设置',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用生物识别登录'),
                    subtitle: Text(state.biometricSettings.biometricType),
                    value: state.biometricSettings.isEnabled,
                    onChanged: (value) {
                      context
                          .read<SecurityBloc>()
                          .add(ToggleBiometricLogin(value));
                    },
                    secondary: const Icon(Icons.fingerprint),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('需要重新验证'),
                    subtitle: Text(
                        '${state.biometricSettings.reauthenticationInterval}秒后需要重新验证'),
                    value: state.biometricSettings.requireReauthentication,
                    onChanged: (value) {
                      // 这里可以添加修改重新验证设置的逻辑
                    },
                    secondary: const Icon(Icons.lock_outline),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<SecurityBloc>().add(VerifyBiometric());
                      },
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('验证生物识别'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 加密设置卡片
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加密设置',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用端到端加密'),
                    subtitle: Text(state.encryptionSettings.algorithm),
                    value: state.encryptionSettings.isEnabled,
                    onChanged: (value) {
                      context
                          .read<SecurityBloc>()
                          .add(ToggleEndToEndEncryption(value));
                    },
                    secondary: const Icon(Icons.security_outlined),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('自动密钥更新'),
                    subtitle: Text(
                        '每${state.encryptionSettings.keyUpdateInterval}天自动更新密钥'),
                    value: state.encryptionSettings.isAutoKeyUpdateEnabled,
                    onChanged: (value) {
                      // 这里可以添加修改自动密钥更新设置的逻辑
                    },
                    secondary: const Icon(Icons.autorenew_outlined),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('上次密钥更新'),
                    subtitle: Text(
                      '${state.encryptionSettings.lastKeyUpdateAt.year}-${state.encryptionSettings.lastKeyUpdateAt.month.toString().padLeft(2, '0')}-${state.encryptionSettings.lastKeyUpdateAt.day.toString().padLeft(2, '0')}',
                    ),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 安全提示卡片
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '安全提示',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• 启用生物识别登录可以提高应用的安全性和便捷性\n• 端到端加密可以保护您的数据不被第三方访问\n• 定期更新密钥可以提高加密的安全性\n• 请妥善保管您的设备，避免生物识别信息泄露',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
