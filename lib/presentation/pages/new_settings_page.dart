import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/presentation/pages/admin_users_page.dart';
import 'package:moment_keep/presentation/pages/user_info_page.dart';
import 'package:moment_keep/core/utils/theme_manager.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';


class NewSettingsPage extends ConsumerStatefulWidget {
  const NewSettingsPage({super.key});

  @override
  ConsumerState<NewSettingsPage> createState() => _NewSettingsPageState();
}

class _NewSettingsPageState extends ConsumerState<NewSettingsPage> {
  final ThemeManager _themeManager = ThemeManager.instance;
  String _storagePath = '';
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
  }

  /// 加载存储路径
  Future<void> _loadStoragePath() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('storage_path');

      if (savedPath != null && savedPath.isNotEmpty) {
        setState(() {
          _storagePath = savedPath;
        });
      } else {
        // 使用默认路径
        final defaultPath = await _getDefaultStoragePath();
        setState(() {
          _storagePath = defaultPath;
        });
      }
    } catch (e) {
      debugPrint('Error loading storage path: $e');
      // 使用默认路径
      final defaultPath = await _getDefaultStoragePath();
      setState(() {
        _storagePath = defaultPath;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取默认存储路径
  Future<String> _getDefaultStoragePath() async {
    // 检查是否为Web平台
    if (kIsWeb) {
      // Web平台返回一个虚拟路径
      return 'web/MomentKeep';
    }

    Directory directory;
    if (Platform.isAndroid || Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      // 在Windows平台上正确拼接路径，添加路径分隔符
      directory = Directory('${Platform.environment['USERPROFILE']}${Platform.pathSeparator}Documents');
    } else if (Platform.isMacOS) {
      directory = Directory('${Platform.environment['HOME']}/Documents');
    } else if (Platform.isLinux) {
      directory = Directory('${Platform.environment['HOME']}/Documents');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    
    // 使用Path分隔符常量来确保跨平台兼容性
    return '${directory.path}${Platform.pathSeparator}MomentKeep';
  }

  /// 选择存储路径
  Future<void> _selectStoragePath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择存储位置',
      );

      if (result != null) {
        // 保存选择的路径
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('storage_path', result);

        setState(() {
          _storagePath = result;
        });

        if (!mounted) return;
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('存储位置已更新为: $result')),
        );
      }
    } catch (e) {
      debugPrint('Error selecting storage path: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择存储位置失败: $e')),
      );
    }
  }

  /// 重置存储路径为默认值
  Future<void> _resetStoragePath() async {
    try {
      final defaultPath = await _getDefaultStoragePath();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('storage_path', defaultPath);

      setState(() {
        _storagePath = defaultPath;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('存储位置已重置为默认值')),
      );
    } catch (e) {
      debugPrint('Error resetting storage path: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重置存储位置失败: $e')),
      );
    }
  }

  /// 显示头像选择菜单
  void _showAvatarSelectionMenu(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择头像'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('拍照'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('从相册选择'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    ).then((result) async {
      if (result != null) {
        await _getImage(result, userId);
      }
    });
  }

  /// 获取图片
  Future<void> _getImage(ImageSource source, String userId) async {
    final pickedFile = await _imagePicker.pickImage(source: source);

    if (pickedFile != null) {
      await _cropImage(File(pickedFile.path), userId);
    }
  }

  /// 裁剪图片
  Future<void> _cropImage(File imageFile, String userId) async {
    // 检查当前平台
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux || 
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Web或桌面平台直接使用原图，不裁剪
      await _updateAvatar(imageFile, userId);
      return;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile != null) {
        await _updateAvatar(File(croppedFile.path), userId);
      }
    } catch (e) {
      // 如果裁剪失败，直接使用原图
      debugPrint('裁剪失败: $e');
      await _updateAvatar(imageFile, userId);
    }
  }

  /// 更新用户头像
  Future<void> _updateAvatar(File imageFile, String userId) async {
    try {
      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      // 创建用户头像目录
      final avatarDirectory = Directory('${directory.path}/avatars/$userId');
      if (!await avatarDirectory.exists()) {
        await avatarDirectory.create(recursive: true);
      }
      // 生成唯一文件名
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final avatarPath = '${avatarDirectory.path}/$fileName';
      // 保存文件
      final savedFile = await imageFile.copy(avatarPath);
      
      // 更新数据库中的用户头像
      final db = await DatabaseService().database;
      await db.update(
        'users',
        {'avatar_url': savedFile.path},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (!mounted) return;
      // 重新加载安全设置，更新UI
      context.read<SecurityBloc>().add(LoadSecuritySettings());
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像更新成功')),
      );
    } catch (e) {
      debugPrint('更新头像失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新头像失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (context) => SecurityBloc()..add(LoadSecuritySettings())),
          BlocProvider(
              create: (context) => RecycleBinBloc()..add(LoadRecycleBin())),
        ],
        child: BlocBuilder<SecurityBloc, SecurityState>(
          builder: (context, securityState) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户信息卡片
                  if (securityState is SecurityLoaded)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 头像
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: securityState.userAuth.avatar != null
                                  ? Image.file(
                                      File(securityState.userAuth.avatar!),
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Text(
                                          securityState.userAuth.username.isNotEmpty
                                              ? securityState.userAuth.username[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 用户信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      securityState.userAuth.username,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'PRO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  securityState.userAuth.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sync,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '上次同步: 刚刚',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 通用设置
                  _SettingsSection(
                    title: '通用设置',
                    children: [
                      // 通知提醒
                      _SettingsItem(
                        icon: Icons.notifications,
                        iconColor: Colors.orange,
                        title: '通知提醒',
                        trailing: _CustomSwitch(value: true, onChanged: (val) {}),
                      ),
                      // 主题风格
                      _ThemeSelector(
                        theme: theme,
                        currentThemeType: _themeManager.currentThemeType,
                        onThemeChanged: (type) {
                          _themeManager.setThemeType(type);
                        },
                      ),
                      // 多语言
                      _SettingsItem(
                        icon: Icons.language,
                        iconColor: Colors.blue,
                        title: '多语言',
                        trailing: Row(
                          children: [
                            Text(
                              '简体中文',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      // 应用锁
                      _SettingsItem(
                        icon: Icons.lock,
                        iconColor: Colors.green,
                        title: '应用锁 (FaceID)',
                        trailing: _CustomSwitch(value: false, onChanged: (val) {}),
                      ),
                    ],
                  ),

                  // 功能配置
                  _SettingsSection(
                    title: '功能配置',
                    children: [
                      // 存储设置
                      _SettingsItem(
                        icon: Icons.folder,
                        iconColor: Colors.brown,
                        title: '存储位置',
                        subtitle: _storagePath,
                        onTap: () {
                          _selectStoragePath();
                        },
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      // 重置存储路径
                      _SettingsItem(
                        icon: Icons.restore,
                        iconColor: Colors.blue,
                        title: '重置存储位置',
                        subtitle: '将存储位置重置为默认值',
                        onTap: () {
                          _resetStoragePath();
                        },
                      ),
                      // 回收箱保留时间
                      BlocBuilder<RecycleBinBloc, RecycleBinState>(
                        builder: (context, recycleBinState) {
                          int retentionDays = 30;
                          if (recycleBinState is RecycleBinLoaded) {
                            retentionDays = recycleBinState.retentionDays;
                          }

                          // 创建一个临时控制器，用于处理数字输入
                          final TextEditingController controller = TextEditingController(
                            text: retentionDays.toString(),
                          );

                          return Column(
                            children: [
                              _SettingsItem(
                                icon: Icons.delete_sweep,
                                iconColor: Colors.red,
                                title: '回收箱保留时间',
                                subtitle: '回收箱中的项目将保留 $retentionDays 天',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: theme.colorScheme.outline),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      isDense: true,
                                      counterText: '',
                                      suffixText: '天',
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    textAlign: TextAlign.center,
                                    onChanged: (value) {
                                      final int? parsedValue = int.tryParse(value);
                                      if (parsedValue != null && parsedValue >= 1 && parsedValue <= 90) {
                                        context.read<RecycleBinBloc>().add(
                                              SetRecycleBinRetentionDays(parsedValue),
                                            );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                      // 生物识别登录
                      if (securityState is SecurityLoaded)
                        Column(
                          children: [
                            _SettingsItem(
                              icon: Icons.fingerprint,
                              iconColor: Colors.purple,
                              title: '启用生物识别登录',
                              subtitle: securityState.biometricSettings.biometricType,
                              trailing: _CustomSwitch(
                                value: securityState.biometricSettings.isEnabled,
                                onChanged: (value) {
                                  context
                                      .read<SecurityBloc>()
                                      .add(ToggleBiometricLogin(value));
                                },
                              ),
                            ),
                            _SettingsItem(
                              icon: Icons.lock,
                              iconColor: Colors.orange,
                              title: '需要重新验证',
                              subtitle: '${securityState.biometricSettings.reauthenticationInterval}秒后需要重新验证',
                              trailing: _CustomSwitch(
                                value: securityState.biometricSettings.requireReauthentication,
                                onChanged: (value) {
                                  // 这里可以添加修改重新验证设置的逻辑
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.only(top: 8, bottom: 4, left: 50, right: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context
                                        .read<SecurityBloc>()
                                        .add(VerifyBiometric());
                                  },
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('验证生物识别'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // 端到端加密
                      if (securityState is SecurityLoaded)
                        _SettingsItem(
                          icon: Icons.security,
                          iconColor: Colors.blueGrey,
                          title: '启用端到端加密',
                          subtitle: securityState.encryptionSettings.algorithm,
                          trailing: _CustomSwitch(
                            value: securityState.encryptionSettings.isEnabled,
                            onChanged: (value) {
                              context
                                  .read<SecurityBloc>()
                                  .add(ToggleEndToEndEncryption(value));
                            },
                          ),
                        ),
                      // 退积分时间设置
                      _RefundTimeSettings(),
                      // 积分设置
                      _PointsSettings(),
                    ],
                  ),

                  // 其他
                  _SettingsSection(
                    title: '其他',
                    children: [
                      // 帮助与反馈
                      _SettingsItem(
                        icon: Icons.help,
                        iconColor: Colors.grey,
                        title: '帮助与反馈',
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      // 关于我们
                      _SettingsItem(
                        icon: Icons.info,
                        iconColor: Colors.grey,
                        title: '关于我们',
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  // 管理员功能
                  if (securityState is SecurityLoaded && securityState.userAuth.isAdmin)
                    _SettingsSection(
                      title: '管理员功能',
                      children: [
                        _SettingsItem(
                          icon: Icons.people,
                          iconColor: Colors.red,
                          title: '用户管理',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminUsersPage(),
                              ),
                            );
                          },
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                  // 退出登录按钮
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('退出登录'),
                            content: const Text('确定要退出登录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // 触发退出登录事件
                                  context.read<SecurityBloc>().add(LogoutEvent());
                                  // 跳转到登录页面
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (route) => false,
                                  );
                                },
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: const Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // 版本信息
                  Center(
                    child: Text(
                      'Version 1.0.2 (Build 20231025)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),

    );
  }
}

/// 设置项组件
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // 标题和副标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // 尾随组件
            if (trailing != null)
              trailing!,
          ],
        ),
      ),
    );
  }
}

/// 设置分组组件
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // 容器
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: children.map((child) {
                final index = children.indexOf(child);
                return Column(
                  children: [
                    child,
                    if (index < children.length - 1)
                      Divider(
                        color: theme.colorScheme.outlineVariant,
                        height: 1,
                        indent: 60,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 自定义开关组件
class _CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: value ? theme.colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 主题选择器
class _ThemeSelector extends StatelessWidget {
  final ThemeData theme;
  final ThemeType currentThemeType;
  final ValueChanged<ThemeType> onThemeChanged;

  const _ThemeSelector({
    required this.theme,
    required this.currentThemeType,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          // 主题标题
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题风格',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '选择你喜欢的界面色彩',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 主题列表
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 简约绿
                _ThemeOption(
                  title: '简约绿',
                  isSelected: currentThemeType == ThemeType.simpleGreen,
                  onTap: () {
                    onThemeChanged(ThemeType.simpleGreen);
                  },
                  preview: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFf6f8f6),
                    ),
                    child: Stack(
                      children: [
                        // 状态栏
                        Container(
                          height: 12,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 16),
                        ),
                        // 内容
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Container(
                                height: 40,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 项目1
                              Container(
                                height: 8,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 项目2
                              Container(
                                height: 8,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 缤纷活力
                _ThemeOption(
                  title: '缤纷活力',
                  isSelected: currentThemeType == ThemeType.vibrant,
                  onTap: () {
                    onThemeChanged(ThemeType.vibrant);
                  },
                  preview: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.pink.shade50,
                      border: Border.all(
                        color: Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 渐变背景
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                Colors.purple,
                                Colors.pink,
                                Colors.blue,
                              ],
                              stops: [0.3, 0.6, 0.9],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                        ),
                        // 内容
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Container(
                                height: 40,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 项目1
                              Container(
                                height: 8,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 项目2
                              Container(
                                height: 8,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 暗夜
                _ThemeOption(
                  title: '暗夜',
                  isSelected: currentThemeType == ThemeType.darkNight,
                  onTap: () {
                    onThemeChanged(ThemeType.darkNight);
                  },
                  preview: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF102216),
                      border: Border.all(
                        color: Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 内容
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Container(
                                height: 40,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 项目1
                              Container(
                                height: 8,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 项目2
                              Container(
                                height: 8,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题选项
class _ThemeOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget preview;

  const _ThemeOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            // 预览
            Container(
              width: 100,
              height: 166,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  preview,
                  // 选中标记
                  if (isSelected)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.check,
                          color: theme.colorScheme.onPrimary,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 标题
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 退积分时间设置组件
class _RefundTimeSettings extends ConsumerStatefulWidget {
  const _RefundTimeSettings();

  @override
  ConsumerState<_RefundTimeSettings> createState() => _RefundTimeSettingsState();
}

class _RefundTimeSettingsState extends ConsumerState<_RefundTimeSettings> {
  int _days = 7;
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefundSettings();
  }

  /// 加载退积分设置
  Future<void> _loadRefundSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseService();
      final settings = await db.getRefundSettings();
      if (settings != null) {
        setState(() {
          _days = settings['days'] as int;
          _hours = settings['hours'] as int;
          _minutes = settings['minutes'] as int;
          _seconds = settings['seconds'] as int;
        });
      }
    } catch (e) {
      debugPrint('Error loading refund settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存退积分设置
  Future<void> _saveRefundSettings() async {
    try {
      final db = DatabaseService();
      await db.updateRefundSettings({
        'days': _days,
        'hours': _hours,
        'minutes': _minutes,
        'seconds': _seconds,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('退积分设置已保存')),
      );
    } catch (e) {
      debugPrint('Error saving refund settings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存退积分设置失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timer,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '退积分时间设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '兑换后多长时间内允许申请退积分',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 时间设置
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeSettingItem(
                label: '天',
                value: _days,
                onChanged: (value) {
                  setState(() {
                    _days = value;
                  });
                  _saveRefundSettings();
                },
                min: 0,
                max: 30,
              ),
              _TimeSettingItem(
                label: '小时',
                value: _hours,
                onChanged: (value) {
                  setState(() {
                    _hours = value;
                  });
                  _saveRefundSettings();
                },
                min: 0,
                max: 23,
              ),
              _TimeSettingItem(
                label: '分钟',
                value: _minutes,
                onChanged: (value) {
                  setState(() {
                    _minutes = value;
                  });
                  _saveRefundSettings();
                },
                min: 0,
                max: 59,
              ),
              _TimeSettingItem(
                label: '秒',
                value: _seconds,
                onChanged: (value) {
                  setState(() {
                    _seconds = value;
                  });
                  _saveRefundSettings();
                },
                min: 0,
                max: 59,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 时间设置项组件
class _TimeSettingItem extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const _TimeSettingItem({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 增减按钮
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceVariant,
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              // 增加按钮
              IconButton(
                onPressed: () {
                  if (value < max) {
                    onChanged(value + 1);
                  }
                },
                icon: Icon(
                  Icons.add,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
                padding: const EdgeInsets.all(8),
              ),
              // 值
              Text(
                value.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              // 减少按钮
              IconButton(
                onPressed: () {
                  if (value > min) {
                    onChanged(value - 1);
                  }
                },
                icon: Icon(
                  Icons.remove,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 标签
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 积分设置组件
class _PointsSettings extends ConsumerStatefulWidget {
  const _PointsSettings();

  @override
  ConsumerState<_PointsSettings> createState() => _PointsSettingsState();
}

class _PointsSettingsState extends ConsumerState<_PointsSettings> {
  // 积分设置状态
  int _pointsPerDiary = 5;
  int _pointsPerTodo = 5;
  int _maxDiaryPointsPerDay = 50;
  int _maxTodoPointsPerDay = 50;
  bool _isLoading = true;
  
  // 输入控制器
  final TextEditingController _diaryPointsController = TextEditingController();
  final TextEditingController _todoPointsController = TextEditingController();
  final TextEditingController _maxDiaryPointsController = TextEditingController();
  final TextEditingController _maxTodoPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPointsSettings();
  }

  @override
  void dispose() {
    _diaryPointsController.dispose();
    _todoPointsController.dispose();
    _maxDiaryPointsController.dispose();
    _maxTodoPointsController.dispose();
    super.dispose();
  }

  /// 加载积分设置
  Future<void> _loadPointsSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pointsPerDiary = prefs.getInt('points_per_diary') ?? 5;
        _pointsPerTodo = prefs.getInt('points_per_todo') ?? 5;
        _maxDiaryPointsPerDay = prefs.getInt('max_diary_points_per_day') ?? 50;
        _maxTodoPointsPerDay = prefs.getInt('max_todo_points_per_day') ?? 50;
        
        // 更新控制器
        _diaryPointsController.text = _pointsPerDiary.toString();
        _todoPointsController.text = _pointsPerTodo.toString();
        _maxDiaryPointsController.text = _maxDiaryPointsPerDay.toString();
        _maxTodoPointsController.text = _maxTodoPointsPerDay.toString();
      });
    } catch (e) {
      debugPrint('Error loading points settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存积分设置
  Future<void> _savePointsSettings() async {
    try {
      // 验证最大值是否大于等于基础值
      if (_maxDiaryPointsPerDay < _pointsPerDiary) {
        _maxDiaryPointsPerDay = _pointsPerDiary;
        _maxDiaryPointsController.text = _maxDiaryPointsPerDay.toString();
      }
      if (_maxTodoPointsPerDay < _pointsPerTodo) {
        _maxTodoPointsPerDay = _pointsPerTodo;
        _maxTodoPointsController.text = _maxTodoPointsPerDay.toString();
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('points_per_diary', _pointsPerDiary);
      await prefs.setInt('points_per_todo', _pointsPerTodo);
      await prefs.setInt('max_diary_points_per_day', _maxDiaryPointsPerDay);
      await prefs.setInt('max_todo_points_per_day', _maxTodoPointsPerDay);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('积分设置已保存')),
      );
    } catch (e) {
      debugPrint('Error saving points settings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存积分设置失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.stars,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '积分设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '设置完成任务获得的积分和每日上限',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 积分设置项
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 日记积分设置
                _buildPointsRow(
                  title: '日记',
                  pointsController: _diaryPointsController,
                  maxPointsController: _maxDiaryPointsController,
                  pointsValue: _pointsPerDiary,
                  maxPointsValue: _maxDiaryPointsPerDay,
                  unit: '/篇',
                  onPointsChanged: (value) {
                    setState(() {
                      _pointsPerDiary = value;
                    });
                    _savePointsSettings();
                  },
                  onMaxPointsChanged: (value) {
                    setState(() {
                      _maxDiaryPointsPerDay = value;
                    });
                    _savePointsSettings();
                  },
                ),
                const SizedBox(height: 16),
                // 待办积分设置
                _buildPointsRow(
                  title: '待办',
                  pointsController: _todoPointsController,
                  maxPointsController: _maxTodoPointsController,
                  pointsValue: _pointsPerTodo,
                  maxPointsValue: _maxTodoPointsPerDay,
                  unit: '/项',
                  onPointsChanged: (value) {
                    setState(() {
                      _pointsPerTodo = value;
                    });
                    _savePointsSettings();
                  },
                  onMaxPointsChanged: (value) {
                    setState(() {
                      _maxTodoPointsPerDay = value;
                    });
                    _savePointsSettings();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建积分设置行
  Widget _buildPointsRow({
    required String title,
    required TextEditingController pointsController,
    required TextEditingController maxPointsController,
    required int pointsValue,
    required int maxPointsValue,
    required String unit,
    required ValueChanged<int> onPointsChanged,
    required ValueChanged<int> onMaxPointsChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：标题 + 积分/篇
        Row(
          children: [
            Text(
              '$title:',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            // 积分值编辑框
            SizedBox(
              width: 50,
              child: TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                  counterText: '',
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                textAlign: TextAlign.center,
                onChanged: (value) {
                  final int? parsedValue = int.tryParse(value);
                  if (parsedValue != null && parsedValue > 0) {
                    onPointsChanged(parsedValue);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // 星星图标
            const Text(
              '✨',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // 右侧：最多 + 积分/天
        Row(
          children: [
            Text(
              '最多:',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            // 最大积分值编辑框
            SizedBox(
              width: 60,
              child: TextField(
                controller: maxPointsController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                  counterText: '',
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                textAlign: TextAlign.center,
                onChanged: (value) {
                  final int? parsedValue = int.tryParse(value);
                  if (parsedValue != null && parsedValue > 0) {
                    onMaxPointsChanged(parsedValue);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // 星星图标
            const Text(
              '✨',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/天',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

