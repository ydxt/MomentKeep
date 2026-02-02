import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:moment_keep/core/utils/theme_manager.dart';
import 'package:moment_keep/core/theme/app_theme.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _ThemeCard extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ThemeCard({
    required this.title,
    required this.description,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isSelected ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 12,
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, height: 1.2),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
      directory = Directory('${Platform.environment['USERPROFILE']}Documents');
    } else if (Platform.isMacOS) {
      directory = Directory('${Platform.environment['HOME']}/Documents');
    } else if (Platform.isLinux) {
      directory = Directory('${Platform.environment['HOME']}/Documents');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    return '${directory.path}/MomentKeep';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户信息卡片
                  if (securityState is SecurityLoaded)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                            // 头像和基本信息行
                            Row(
                              children: [
                                // 头像
                                GestureDetector(
                                  onTap: () {
                                    // 打开头像选择菜单
                                    _showAvatarSelectionMenu(context, securityState.userAuth.id);
                                  },
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: theme.colorScheme.primary,
                                        backgroundImage: securityState.userAuth.avatar != null
                                            ? FileImage(File(securityState.userAuth.avatar!))
                                            : null,
                                        child: securityState.userAuth.avatar == null
                                            ? Text(
                                                securityState.userAuth.username.isNotEmpty
                                                    ? securityState.userAuth.username[0].toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 用户名和邮箱
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        securityState.userAuth.username,
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        securityState.userAuth.email,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // 详细信息列表
                            ListTile(
                              leading: const Icon(Icons.access_time_outlined),
                              title: const Text('上次登录'),
                              subtitle: Text(
                                '${securityState.userAuth.lastLoginAt.year}-${securityState.userAuth.lastLoginAt.month.toString().padLeft(2, '0')}-${securityState.userAuth.lastLoginAt.day.toString().padLeft(2, '0')} ${securityState.userAuth.lastLoginAt.hour.toString().padLeft(2, '0')}:${securityState.userAuth.lastLoginAt.minute.toString().padLeft(2, '0')}',
                              ),
                              dense: true,
                            ),
                            ListTile(
                              leading: const Icon(Icons.calendar_month_outlined),
                              title: const Text('注册时间'),
                              subtitle: Text(
                                '${securityState.userAuth.createdAt.year}-${securityState.userAuth.createdAt.month.toString().padLeft(2, '0')}-${securityState.userAuth.createdAt.day.toString().padLeft(2, '0')}',
                              ),
                              dense: true,
                            ),
                            if (securityState.userAuth.isAdmin)
                              ListTile(
                                leading: const Icon(Icons.admin_panel_settings_outlined),
                                title: const Text('管理员权限'),
                                subtitle: const Text('拥有所有用户数据管理权限'),
                                dense: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (securityState is SecurityLoaded && securityState.userAuth.isAdmin)
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        // 管理员功能卡片
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '管理员功能',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // 跳转到用户管理页面
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AdminUsersPage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.people_outline),
                                    label: const Text('用户管理'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '管理员可以查看、编辑和删除所有用户的数据。',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  if (securityState is SecurityLoaded && !securityState.userAuth.isAdmin)
                    const SizedBox(height: 24),

                  // 主题设置卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '主题设置',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '主题模式',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            title: const Text('跟随系统'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.system,
                              groupValue: _themeManager.currentThemeMode,
                              onChanged: (value) {
                                if (value != null) {
                                  _themeManager.setThemeMode(value);
                                }
                              },
                            ),
                          ),
                          ListTile(
                            title: const Text('浅色主题'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.light,
                              groupValue: _themeManager.currentThemeMode,
                              onChanged: (value) {
                                if (value != null) {
                                  _themeManager.setThemeMode(value);
                                }
                              },
                            ),
                          ),
                          ListTile(
                            title: const Text('深色主题'),
                            leading: Radio<ThemeMode>(
                              value: ThemeMode.dark,
                              groupValue: _themeManager.currentThemeMode,
                              onChanged: (value) {
                                if (value != null) {
                                  _themeManager.setThemeMode(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            '主题配色',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 3, // 3列布局，更适合3个主题
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 2.2, // 调整卡片比例
                            children: [
                              _ThemeCard(
                                title: '简约绿',
                                description: '简约清新的绿色主题',
                                color: const Color(0xFF13EC5B),
                                isSelected: _themeManager.currentThemeType ==
                                    ThemeType.simpleGreen,
                                onTap: () {
                                  _themeManager
                                      .setThemeType(ThemeType.simpleGreen);
                                },
                                theme: theme,
                              ),
                              _ThemeCard(
                                title: '缤纷活力',
                                description: '充满活力的多彩主题',
                                color: const Color(0xFFFF6B6B),
                                isSelected: _themeManager.currentThemeType ==
                                    ThemeType.vibrant,
                                onTap: () {
                                  _themeManager.setThemeType(ThemeType.vibrant);
                                },
                                theme: theme,
                              ),
                              _ThemeCard(
                                title: '暗夜',
                                description: '炫酷的深色主题',
                                color: const Color(0xFF00FF88),
                                isSelected: _themeManager.currentThemeType ==
                                    ThemeType.darkNight,
                                onTap: () {
                                  _themeManager.setThemeType(ThemeType.darkNight);
                                },
                                theme: theme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 存储设置卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '存储设置',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            title: const Text('存储位置'),
                            subtitle: Text(_storagePath),
                            leading: const Icon(Icons.folder_outlined),
                            trailing: ElevatedButton.icon(
                              onPressed: _selectStoragePath,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('更改'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _resetStoragePath,
                              icon: const Icon(Icons.restore_outlined),
                              label: const Text('重置为默认位置'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '所有资源（图片、音频、数据库、日记等）将存储在上述路径下。',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 回收箱设置卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '回收箱设置',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<RecycleBinBloc, RecycleBinState>(
                            builder: (context, recycleBinState) {
                              int retentionDays = 30;
                              if (recycleBinState is RecycleBinLoaded) {
                                retentionDays = recycleBinState.retentionDays;
                              }

                              return Column(
                                children: [
                                  ListTile(
                                    title: const Text('回收箱保留时间'),
                                    subtitle:
                                        Text('回收箱中的项目将保留 $retentionDays 天'),
                                    leading:
                                        const Icon(Icons.delete_sweep_outlined),
                                  ),
                                  const SizedBox(height: 8),
                                  Slider(
                                    value: retentionDays.toDouble(),
                                    min: 1,
                                    max: 90,
                                    divisions: 89,
                                    label: '$retentionDays 天',
                                    onChanged: (value) {
                                      context.read<RecycleBinBloc>().add(
                                            SetRecycleBinRetentionDays(
                                                value.toInt()),
                                          );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('1天',
                                          style: theme.textTheme.bodySmall),
                                      Text('30天',
                                          style: theme.textTheme.bodySmall),
                                      Text('90天',
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '超过保留时间的项目将被自动清理。',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 生物识别设置卡片
                  if (securityState is SecurityLoaded)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                              subtitle: Text(securityState
                                  .biometricSettings.biometricType),
                              value: securityState.biometricSettings.isEnabled,
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
                                  '${securityState.biometricSettings.reauthenticationInterval}秒后需要重新验证'),
                              value: securityState
                                  .biometricSettings.requireReauthentication,
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
                                  context
                                      .read<SecurityBloc>()
                                      .add(VerifyBiometric());
                                },
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('验证生物识别'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (securityState is SecurityLoaded)
                    const SizedBox(height: 24),

                  // 加密设置卡片
                  if (securityState is SecurityLoaded)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                              subtitle: Text(
                                  securityState.encryptionSettings.algorithm),
                              value: securityState.encryptionSettings.isEnabled,
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
                                  '每${securityState.encryptionSettings.keyUpdateInterval}天自动更新密钥'),
                              value: securityState
                                  .encryptionSettings.isAutoKeyUpdateEnabled,
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
                                '${securityState.encryptionSettings.lastKeyUpdateAt.year}-${securityState.encryptionSettings.lastKeyUpdateAt.month.toString().padLeft(2, '0')}-${securityState.encryptionSettings.lastKeyUpdateAt.day.toString().padLeft(2, '0')}',
                              ),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (securityState is SecurityLoaded)
                    const SizedBox(height: 24),

                  // 安全提示卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 24),

                  // 关于卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '关于',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            title: const Text('版本'),
                            subtitle: const Text('1.0.0'),
                            leading: const Icon(Icons.info_outline),
                            dense: true,
                          ),
                          ListTile(
                            title: const Text('开发者'),
                            subtitle: const Text('Daily Check-in Team'),
                            leading: const Icon(Icons.person_outline),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 退出登录按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 显示确认对话框
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
                      icon: const Icon(Icons.logout),
                      label: const Text('退出登录'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
