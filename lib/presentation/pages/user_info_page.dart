import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/presentation/blocs/security_bloc.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/utils/id_generator.dart';
import 'package:moment_keep/presentation/pages/change_password_page.dart';
import 'package:moment_keep/presentation/pages/change_pay_password_page.dart';
import 'package:moment_keep/presentation/pages/coupons_detail_page.dart';
import 'package:moment_keep/presentation/pages/member_level_page.dart';
import 'package:moment_keep/presentation/pages/shipping_address_page.dart';
import 'package:moment_keep/presentation/pages/shopping_card_page.dart';
import 'package:moment_keep/presentation/pages/new_settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:camera/camera.dart';
import 'package:image_cropper/image_cropper.dart';



class UserInfoPage extends ConsumerStatefulWidget {
  const UserInfoPage({super.key});

  @override
  ConsumerState<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends ConsumerState<UserInfoPage> {
  // 用户信息编辑状态
  String? _editingField;
  String _editingGender = '';
  DateTime? _editingBirthday;
  
  // 本地状态变量，用于非编辑模式显示
  String _displayRealName = '';
  String _displayPhone = '';
  String _displayGender = '';
  DateTime? _displayBirthday;

  // 输入控制器
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _realNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // 加载状态
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isUserDataLoading = false;
  bool _hasLoadedUserDetails = false;
  
  // 用户扩展信息缓存
  Map<String, dynamic>? _userExtendedInfo;

  // 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  // 头像相关
  final ImagePicker _imagePicker = ImagePicker();

  // 获取用户积分
  Future<double> _getUserPoints(String userId) async {
    try {
      return await _databaseService.getUserPoints(userId);
    } catch (e) {
      debugPrint('获取用户积分失败: $e');
      return 0.0;
    }
  }

  // 获取用户会员等级
  Future<String> _getUserMemberLevel(String userId) async {
    try {
      final userDatabase = UserDatabaseService();
      final userData = await userDatabase.getUserById(userId);
      if (userData != null && userData.containsKey('member_level')) {
        final memberLevel = userData['member_level'];
        // 根据会员等级返回对应的等级名称
        switch (memberLevel) {
          case 0:
            return '普通会员';
          case 1:
            return 'VIP会员';
          case 2:
            return '黄金会员';
          case 3:
            return '铂金会员';
          case 4:
            return '钻石会员';
          default:
            return '普通会员';
        }
      }
      return '普通会员';
    } catch (e) {
      debugPrint('获取用户会员等级失败: $e');
      return '普通会员';
    }
  }

  // 获取用户优惠券数量
  Future<int> _getUserCouponCount(String userId) async {
    try {
      // 使用DatabaseService获取真实的优惠券数量
      final databaseService = DatabaseService();
      return await databaseService.getUserCouponCount(userId);
    } catch (e) {
      debugPrint('获取用户优惠券数量失败: $e');
      return 0;
    }
  }

  // 获取用户红包数量
  Future<int> _getUserRedPacketCount(String userId) async {
    try {
      // 使用DatabaseService获取真实的红包数量
      final databaseService = DatabaseService();
      return await databaseService.getUserRedPacketCount(userId);
    } catch (e) {
      debugPrint('获取用户红包数量失败: $e');
      return 0;
    }
  }

  // 获取用户购物卡数量
  Future<int> _getUserShoppingCardCount(String userId) async {
    try {
      // 使用DatabaseService获取真实的购物卡数量
      final databaseService = DatabaseService();
      return await databaseService.getUserShoppingCardCount(userId);
    } catch (e) {
      debugPrint('获取用户购物卡数量失败: $e');
      return 0;
    }
  }

  // 获取合适的输入控制器
  TextEditingController _getTextFieldController(String title) {
    switch (title) {
      case '昵称':
        return _usernameController;
      case '真实姓名':
        return _realNameController;
      case '手机号':
        return _phoneController;
      case '邮箱':
        return _emailController;
      default:
        return TextEditingController();
    }
  }

  @override
  void initState() {
    super.initState();
    // 加载用户信息
    context.read<SecurityBloc>().add(LoadSecuritySettings());
  }

  @override
  void dispose() {
    // 销毁控制器
    _usernameController.dispose();
    _realNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  // 从数据库加载用户扩展信息（会员等级、积分、优惠券、红包、购物卡）
  Future<void> _loadUserExtendedInfo(String userId) async {
    try {
      final [memberLevel, points, couponCount, redPacketCount, shoppingCardCount] = await Future.wait([
        _getUserMemberLevel(userId),
        _getUserPoints(userId),
        _getUserCouponCount(userId),
        _getUserRedPacketCount(userId),
        _getUserShoppingCardCount(userId),
      ]);
      
      setState(() {
        _userExtendedInfo = {
          'memberLevel': memberLevel,
          'points': points,
          'couponCount': couponCount,
          'redPacketCount': redPacketCount,
          'shoppingCardCount': shoppingCardCount,
        };
      });
    } catch (e) {
      debugPrint('加载用户扩展信息失败: $e');
      // 设置默认值
      setState(() {
        _userExtendedInfo = {
          'memberLevel': '普通会员',
          'points': 0,
          'couponCount': 0,
          'redPacketCount': 0,
          'shoppingCardCount': 0,
        };
      });
    }
  }
  
  // 从数据库加载用户详细信息
  Future<void> _loadUserDetails(String userId) async {
    setState(() {
      _isUserDataLoading = true;
    });
    
    try {
      final userDatabase = UserDatabaseService();
      final userData = await userDatabase.getUserById(userId);
      
      if (userData != null) {
        // 获取用户详情数据
        final realName = userData['real_name'] as String? ?? '';
        final phone = userData['phone'] as String? ?? '';
        
        setState(() {
          // 处理性别字段，将整数转换为字符串
          final genderValue = userData['gender'];
          String genderStr = '';
          if (genderValue is int) {
            genderStr = genderValue == 1 ? '男' : genderValue == 2 ? '女' : '';
          } else {
            genderStr = genderValue as String? ?? '';
          }
          _editingGender = genderStr;
          _displayGender = genderStr;
          
          final birthdayStr = userData['birthday'] as String?;
          DateTime? birthday;
          if (birthdayStr != null && birthdayStr.isNotEmpty) {
            birthday = DateTime.tryParse(birthdayStr);
          }
          _editingBirthday = birthday;
          _displayBirthday = birthday;
          
          // 更新控制器的值
          _realNameController.text = realName;
          _phoneController.text = phone;
          
          // 更新本地状态变量，用于非编辑模式显示
          _displayRealName = realName;
          _displayPhone = phone;
        });
      }
      
      // 加载扩展信息
      await _loadUserExtendedInfo(userId);
    } catch (e) {
      _showError('加载用户详情失败: $e');
    } finally {
      setState(() {
        _isUserDataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return BlocBuilder<SecurityBloc, SecurityState>(
      builder: (context, state) {
        if (state is SecurityLoading) {
          return Scaffold(
            backgroundColor: theme.colorScheme.background,
            body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
          );
        }

        if (state is! SecurityLoaded) {
          return Scaffold(
            backgroundColor: theme.colorScheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '加载用户信息失败',
                    style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SecurityBloc>().add(LoadSecuritySettings());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            ),
          );
        }

        final userAuth = state.userAuth;

        // 初始化编辑字段并从数据库加载详细信息
        // 直接更新控制器的值，不经过中间状态变量
        if (_editingField != '昵称' && _usernameController.text != userAuth.username) {
          _usernameController.text = userAuth.username;
        }
        if (_editingField != '邮箱' && _emailController.text != userAuth.email) {
          _emailController.text = userAuth.email;
        }
        // 从数据库加载用户详细信息，只加载一次
        if (!_hasLoadedUserDetails) {
          _hasLoadedUserDetails = true;
          // 延迟到构建完成后执行，避免setState() called during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUserDetails(userAuth.id);
          });
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: Stack(
            children: [
              // 主内容
              SingleChildScrollView(
                child: Column(
                  children: [
                    // 顶部状态栏占位
                    SizedBox(height: MediaQuery.of(context).padding.top),
                    
                    // 顶部导航栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 占位符，保持标题居中
                          Container(width: 40, height: 40),
                          
                          // 标题
                          Text(
                            '个人信息',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          // 设置按钮
                          GestureDetector(
                            onTap: () {
                              // 导航到设置页面
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => NewSettingsPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              height: 40,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '设置',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 头像区域
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              // 头像
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(56),
                                  border: Border.all(
                                    color: theme.colorScheme.surfaceVariant,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(52),
                                  child: userAuth.avatar != null && userAuth.avatar!.isNotEmpty
                                    ? Image(
                                        image: FileImage(File(userAuth.avatar!)),
                                        fit: BoxFit.cover,
                                        width: 104,
                                        height: 104,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: theme.colorScheme.surfaceVariant,
                                            width: 104,
                                            height: 104,
                                            child: Center(
                                              child: Text(
                                                userAuth.username.isNotEmpty
                                                    ? userAuth.username[0].toUpperCase()
                                                    : 'U',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: theme.colorScheme.surfaceVariant,
                                        width: 104,
                                        height: 104,
                                        child: Center(
                                          child: Text(
                                            userAuth.username.isNotEmpty
                                                ? userAuth.username[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                               
                              // 更换头像按钮
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    _showAvatarOptions();
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: theme.colorScheme.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.shadow,
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: theme.colorScheme.background,
                                        width: 3,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.photo_camera,
                                      color: theme.colorScheme.onPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // 更换头像提示文字
                          const SizedBox(height: 12),
                          Text(
                            '点击更换头像',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 个人信息列表
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Column(
                        children: [
                          // 昵称
                          _buildInfoItem(
                            title: '昵称',
                            value: _editingField == '昵称' ? _usernameController.text : userAuth.username,
                            showArrow: false,
                            onTap: () {
                              setState(() {
                                _editingField = '昵称';
                              });
                            },
                          ),
                          
                          // 用户ID
                          _buildInfoItem(
                            title: '用户ID',
                            value: _formatUserId(userAuth.id),
                            showCopyButton: true,
                          ),
                          
                          // 真实姓名
                          _buildInfoItem(
                            title: '真实姓名',
                            value: _editingField == '真实姓名' ? _realNameController.text : (_displayRealName.isEmpty ? '未设置' : _displayRealName),
                            showArrow: false,
                            isPlaceholder: _editingField != '真实姓名' && _displayRealName.isEmpty,
                            onTap: () {
                              setState(() {
                                _editingField = '真实姓名';
                              });
                            },
                          ),
                          
                          // 性别
                          _buildInfoItem(
                            title: '性别',
                            value: _editingField == '性别' ? (_editingGender.isEmpty ? '保密' : _editingGender) : (_displayGender.isEmpty ? '保密' : _displayGender),
                            showArrow: false,
                            isPlaceholder: _editingField != '性别' && _displayGender.isEmpty,
                            onTap: () {
                              if (_editingField == '性别') {
                                _showGenderSelection();
                              } else {
                                setState(() {
                                  _editingField = '性别';
                                });
                              }
                            },
                          ),
                          
                          // 生日
                          _buildInfoItem(
                            title: '生日',
                            value: _editingField == '生日' 
                                ? (_editingBirthday != null ? '${_editingBirthday!.year}-${_editingBirthday!.month.toString().padLeft(2, '0')}-${_editingBirthday!.day.toString().padLeft(2, '0')}' : '请选择')
                                : (_displayBirthday != null ? '${_displayBirthday!.year}-${_displayBirthday!.month.toString().padLeft(2, '0')}-${_displayBirthday!.day.toString().padLeft(2, '0')}' : '请选择'),
                            showArrow: false,
                            isPlaceholder: _editingField != '生日' && _displayBirthday == null,
                            onTap: () {
                              if (_editingField == '生日') {
                                _selectBirthday();
                              } else {
                                setState(() {
                                  _editingField = '生日';
                                });
                              }
                            },
                          ),
                          
                          // 手机号
                          _buildInfoItem(
                            title: '手机号',
                            value: _editingField == '手机号' ? _phoneController.text : (_displayPhone.isEmpty ? '未设置' : _displayPhone),
                            showArrow: false,
                            isPlaceholder: _editingField != '手机号' && _displayPhone.isEmpty,
                            onTap: () {
                              setState(() {
                                _editingField = '手机号';
                              });
                            },
                          ),
                          
                          // 邮箱
                          _buildInfoItem(
                            title: '邮箱',
                            value: _editingField == '邮箱' ? _emailController.text : userAuth.email,
                            showArrow: false,
                            onTap: () {
                              setState(() {
                                _editingField = '邮箱';
                              });
                            },
                          ),
                          
                          // 登录密码
                          _buildInfoItem(
                            title: '登录密码',
                            value: '修改',
                            showArrow: false,
                            isPlaceholder: true,
                            onTap: () {
                              _showChangePasswordDialog();
                            },
                          ),
                          
                          // 支付密码
                          _buildInfoItem(
                            title: '支付密码',
                            value: '修改',
                            showArrow: false,
                            isPlaceholder: true,
                            onTap: () {
                              _showChangePayPasswordDialog();
                            },
                          ),
                          
                          // 收货地址
                          _buildInfoItem(
                            title: '收货地址',
                            value: '管理',
                            showArrow: true,
                            isPlaceholder: true,
                            onTap: () {
                              // 收货地址管理页面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ShippingAddressPage(),
                                ),
                              );
                            },
                          ),
                          
                          // 会员等级 / 积分
                          _buildInfoItem(
                            title: '会员等级 / 积分',
                            value: _userExtendedInfo != null 
                                ? '${_userExtendedInfo!['memberLevel']} / ✨${(_userExtendedInfo!['points'] as double).round()}' 
                                : '普通会员 / ✨0',
                            showArrow: true,
                            onTap: () {
                              // 会员等级/积分详情页面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MemberLevelPage(userId: userAuth.id),
                                ),
                              );
                            },
                          ),
                          
                          // 优惠券 / 红包
                          _buildInfoItem(
                            title: '优惠券 / 红包',
                            value: _userExtendedInfo != null 
                                ? '${_userExtendedInfo!['couponCount']}张优惠券 / ${_userExtendedInfo!['redPacketCount']}个红包' 
                                : '0张优惠券 / 0个红包',
                            showArrow: true,
                            onTap: () {
                              // 优惠券/红包详情页面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CouponsDetailPage(userId: userAuth.id),
                                ),
                              );
                            },
                          ),
                          
                          // 购物卡
                          _buildInfoItem(
                            title: '购物卡',
                            value: _userExtendedInfo != null 
                                ? (_userExtendedInfo!['shoppingCardCount'] > 0 ? '${_userExtendedInfo!['shoppingCardCount']}张' : '暂无') 
                                : '暂无',
                            showArrow: true,
                            isPlaceholder: _userExtendedInfo == null || _userExtendedInfo!['shoppingCardCount'] == 0,
                            onTap: () {
                            // 购物卡详情页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShoppingCardPage(userId: userAuth.id),
                              ),
                            );
                          },
                        ),
                        
                        // 退出登录按钮
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              _showLogoutDialog();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('退出登录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      ),
                    ),
                    
                    // 底部间距
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              
              // 加载指示器
              if (_isLoading || _isUpdating || _isUserDataLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  // 构建信息项
  Widget _buildInfoItem({
    required String title,
    required String value,
    bool showArrow = false,
    bool showCopyButton = false,
    bool isPlaceholder = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isEditing = _editingField == title;
    final itemContainer = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 标题
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                // 值和操作按钮
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 编辑模式下根据字段类型显示不同组件
                      Expanded(
                        child: isEditing ? (
                          // 性别和生日字段显示为点击触发选择器的形式
                          (title == '性别' || title == '生日') ? 
                          GestureDetector(
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    value,
                                    style: TextStyle(
                                      color: isPlaceholder ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ) : 
                          // 其他字段显示为输入框
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: theme.colorScheme.primaryContainer,
                              ),
                              controller: _getTextFieldController(title),
                              // 自动获取焦点
                              autofocus: true,
                              // 根据标题设置键盘类型和输入验证
                              keyboardType: title == '邮箱' ? TextInputType.emailAddress : 
                                          title == '手机号' ? TextInputType.phone : 
                                          TextInputType.text,
                              // 根据不同字段设置输入限制
                              inputFormatters: [
                                if (title == '手机号') ...[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                if (title == '昵称') ...[
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                if (title == '真实姓名') ...[
                                  LengthLimitingTextInputFormatter(20),
                                  // 只允许中文、英文和点号（·）
                                  FilteringTextInputFormatter.allow(RegExp(r'^[\u4e00-\u9fa5a-zA-Z·]+$')),
                                ],
                                if (title == '邮箱') ...[
                                  // 允许邮箱格式的字符
                                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9._%+-@]+$')),
                                ],
                              ],
                            ),
                          )
                        ) : 
                        // 非编辑模式下显示文本
                        Text(
                          value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isPlaceholder ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      // 复制按钮
                      if (showCopyButton)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: GestureDetector(
                            onTap: () {
                              _copyToClipboard(value);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.content_copy,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                            ),
                          ),
                        )
                      else if (showArrow && !isEditing)
                        // 箭头
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        )
                      else if (isEditing && onTap != null && title == '生日')
                        // 编辑模式下的选择按钮
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: onTap,
                            child: Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 编辑模式下的保存和取消按钮
            if (isEditing && (title == '昵称' || title == '真实姓名' || title == '手机号' || title == '邮箱' || title == '性别' || title == '生日'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 取消按钮
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingField = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('取消'),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 保存按钮
                    TextButton(
                      onPressed: () {
                        _saveUserInfo(title);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    // 如果提供了onTap回调，将容器包裹在GestureDetector中
    if (onTap != null && !isEditing) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: itemContainer,
      );
    }

    return itemContainer;
  }
  
  // 显示头像选择选项
  void _showAvatarOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.colorScheme.onSurface),
              title: Text('拍照', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.colorScheme.onSurface),
              title: Text('从相册选择', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: theme.colorScheme.error),
              title: Text('取消', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 裁剪照片 - 适配多平台
  Future<CroppedFile?> _cropImage(String imagePath) async {
    // 检查当前平台
    if (Platform.isWindows) {
      // Windows平台直接使用原图，不裁剪
      return CroppedFile(imagePath);
    }
    
    try {
      final theme = Theme.of(context);
      
      // 强制不使用 const，确保运行时动态加载
      return await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: '裁剪头像',
          ),
          WebUiSettings(
            context: context,
            // 移除 presentStyle 等可能引起未定义错误的枚举
            size: const CropperSize(
              width: 500,
              height: 500,
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('裁剪操作异常: $e');
      return null;
    }
  }

  // 选择图片
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    final path = picked?.path;

    if (path != null) {
      // 这里的逻辑：如果 _cropImage 返回 null（用户取消裁剪），
      // 我们就用原始路径 path，从而实现“不选择就是原图”
      final cropped = await _cropImage(path);
      _updateUserAvatar(cropped?.path ?? path); 
    }
  }

  // 抽离出来的头像更新逻辑，保持代码整洁
  Future<void> _updateUserAvatar(String imagePath) async {
    setState(() => _isLoading = true);
    try {
      final securityState = context.read<SecurityBloc>().state;
      if (securityState is SecurityLoaded) {
        final userId = securityState.userAuth.id;
        
        // 获取用户设置的存储路径
        final prefs = await SharedPreferences.getInstance();        
        String storagePath = prefs.getString('storage_path') ?? '';       
        // 如果没有设置存储路径，使用与设置页面相同的默认路径逻辑
        if (storagePath.isEmpty) {
          if (Platform.isWindows) {
            // Windows 平台与设置页面使用相同的默认路径
            storagePath = '${Platform.environment['USERPROFILE']}${Platform.pathSeparator}Documents${Platform.pathSeparator}MomentKeep';
          } else {
            // 其他平台使用应用文档目录
            final documentsDir = await getApplicationDocumentsDirectory();
            storagePath = '${documentsDir.path}${Platform.pathSeparator}MomentKeep';
          }
        }
        
        // 确保路径格式正确
        storagePath = storagePath.replaceAll('/', Platform.pathSeparator);
        storagePath = storagePath.replaceAll('\\', Platform.pathSeparator);        
        // 保存裁剪后的图片到用户设置的目录
        // 使用平台特定的路径分隔符
        final avatarDirectory = Directory('$storagePath${Platform.pathSeparator}$userId${Platform.pathSeparator}avatars');
        
        if (!await avatarDirectory.exists()) {
          await avatarDirectory.create(recursive: true);
        }
        
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final finalPath = '${avatarDirectory.path}/$fileName';
        
        // 检查源文件是否存在
        if (await File(imagePath).exists()) {
          await File(imagePath).copy(finalPath);
        } else {
          throw Exception('源文件不存在');
        }
        
        // 检查目标文件是否存在
        if (!await File(finalPath).exists()) {
          throw Exception('目标文件创建失败');
        }
        
        // 更新数据库
        await UserDatabaseService().updateUser(userId, {}, {'avatar': finalPath});
        
        if (mounted) {
          context.read<SecurityBloc>().add(LoadSecuritySettings());
          _showSuccess('头像设置成功');
        }
      }
    } catch (e) {
      _showError('更新头像失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // 选择生日
  void _selectBirthday() {
    final theme = Theme.of(context);
    showDatePicker(
      context: context,
      initialDate: _editingBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.colorScheme.primary,
              primary: theme.colorScheme.primary,
              surface: theme.colorScheme.surfaceVariant,
              onSurface: theme.colorScheme.onSurface,
              brightness: theme.brightness,
            ),
          ),
          child: child!,
        );
      },
    ).then((date) {
      if (date != null) {
        setState(() {
          _editingBirthday = date;
        });
      }
    });
  }
  
  // 复制到剪贴板
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccess('已复制到剪贴板');
  }
  
  // 显示成功提示
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 显示错误提示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 格式化用户ID为12位数字
  String _formatUserId(String id) {
    // 如果ID已经是12位有效ID，直接返回
    if (IdGenerator.isValidId(id) && id.length == 12) {
      return id;
    }
    
    // 将现有ID转换为12位固定格式，确保同一个原始ID生成相同的12位ID
    // 格式：01（买家前缀） + 固定时间戳（00000） + 原始ID补全5位
    final fixedPrefix = '01'; // 默认买家前缀
    final fixedTimestamp = '00000'; // 固定时间戳
    final paddedId = id.padLeft(5, '0').substring(0, 5);
    
    return '$fixedPrefix$fixedTimestamp$paddedId';
  }
  
  // 显示修改密码对话框
  void _showChangePasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordPage(),
      ),
    );
  }
  
  // 显示优惠券/红包明细
  void _showCouponsDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CouponsDetailPage(),
      ),
    );
  }
  

  
  // 显示性别选择对话框
  void _showGenderSelection() {
    final theme = Theme.of(context);
    // 使用showMenu替代showModalBottomSheet，使其在点击位置弹出
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width - 200, // 从右侧弹出
        offset.dy + 120, // 向下偏移，确保菜单可见
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: [
        PopupMenuItem(
          value: '男',
          child: ListTile(
            leading: Icon(Icons.person, color: theme.colorScheme.onSurface),
            title: Text('男', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ),
        PopupMenuItem(
          value: '女',
          child: ListTile(
            leading: Icon(Icons.person, color: theme.colorScheme.onSurface),
            title: Text('女', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ),
        PopupMenuItem(
          value: '',
          child: ListTile(
            leading: Icon(Icons.person_off, color: theme.colorScheme.onSurfaceVariant),
            title: Text('保密', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
    ).then((value) {
      if (value != null) {
        setState(() {
          _editingGender = value;
        });
      }
    });
  }
  
  // 显示修改支付密码对话框
  void _showChangePayPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePayPasswordPage(),
      ),
    );
  }
  
  // 显示退出登录确认对话框
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SecurityBloc>().add(LogoutEvent());
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  // 验证表单
  bool _validateForm() {
    bool isValid = true;
    
    // 验证昵称
    if (_usernameController.text.isEmpty) {
      _showError('请输入昵称');
      isValid = false;
    } else if (_usernameController.text.length < 2 || _usernameController.text.length > 20) {
      _showError('昵称长度必须在2-20个字符之间');
      isValid = false;
    }
    
    // 验证真实姓名（如果填写了）
    if (_realNameController.text.isNotEmpty) {
      if (_realNameController.text.length < 2 || _realNameController.text.length > 20) {
        _showError('真实姓名长度必须在2-20个字符之间');
        isValid = false;
      } else if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z·]+$').hasMatch(_realNameController.text)) {
        _showError('真实姓名只能包含中文、英文和点号');
        isValid = false;
      }
    }
    
    // 验证邮箱
    if (_emailController.text.isEmpty) {
      _showError('请输入邮箱');
      isValid = false;
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text)) {
      _showError('请输入有效的邮箱地址');
      isValid = false;
    }
    
    // 验证手机号（如果填写了）
    if (_phoneController.text.isNotEmpty) {
      if (_phoneController.text.length != 11) {
        _showError('手机号必须为11位数字');
        isValid = false;
      } else if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text)) {
        _showError('请输入有效的手机号');
        isValid = false;
      }
    }
    
    // 验证性别
    if (_editingGender.isNotEmpty && !['男', '女'].contains(_editingGender)) {
      _showError('性别只能为男、女或保密');
      isValid = false;
    }
    
    // 验证生日
    if (_editingBirthday != null) {
      // 确保生日不是未来日期
      if (_editingBirthday!.isAfter(DateTime.now())) {
        _showError('生日不能是未来日期');
        isValid = false;
      }
      // 确保生日在合理范围内（例如1900年之后）
      if (_editingBirthday!.year < 1900) {
        _showError('生日年份不能早于1900年');
        isValid = false;
      }
    }
    
    return isValid;
  }
  
  // 保存用户信息到数据库
  Future<void> _saveUserInfo(String field) async {
    // 验证表单
    bool isValid = true;
    
    // 根据当前编辑的字段进行验证
    switch (field) {
      case '昵称':
        if (_usernameController.text.isEmpty) {
          _showError('请输入昵称');
          isValid = false;
        } else if (_usernameController.text.length < 2 || _usernameController.text.length > 20) {
          _showError('昵称长度必须在2-20个字符之间');
          isValid = false;
        }
        break;
      case '真实姓名':
        if (_realNameController.text.isNotEmpty) {
          if (_realNameController.text.length < 2 || _realNameController.text.length > 20) {
            _showError('真实姓名长度必须在2-20个字符之间');
            isValid = false;
          } else if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z·]+$').hasMatch(_realNameController.text)) {
            _showError('真实姓名只能包含中文、英文和点号');
            isValid = false;
          }
        }
        break;
      case '邮箱':
        if (_emailController.text.isEmpty) {
          _showError('请输入邮箱');
          isValid = false;
        } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text)) {
          _showError('请输入有效的邮箱地址');
          isValid = false;
        }
        break;
      case '手机号':
        if (_phoneController.text.isNotEmpty) {
          if (_phoneController.text.length != 11) {
            _showError('手机号必须为11位数字');
            isValid = false;
          } else if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text)) {
            _showError('请输入有效的手机号');
            isValid = false;
          }
        }
        break;
      case '性别':
        // 性别不需要验证，用户可以选择保密
        break;
      case '生日':
        // 生日不需要验证，用户可以选择不设置
        break;
    }
    
    if (!isValid) {
      return;
    }
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      // 获取当前用户ID（在异步操作前获取）
      final securityState = context.read<SecurityBloc>().state;
      if (securityState is SecurityLoaded) {
        final userId = securityState.userAuth.id;
        
        // 根据当前编辑的字段构建更新数据
        Map<String, dynamic> updateData = {};
        
        switch (field) {
          case '昵称':
            updateData['nickname'] = _usernameController.text;
            break;
          case '真实姓名':
            updateData['real_name'] = _realNameController.text;
            break;
          case '邮箱':
            updateData['email'] = _emailController.text;
            break;
          case '手机号':
            updateData['phone'] = _phoneController.text;
            break;
          case '性别':
            updateData['gender'] = _editingGender == '男' ? 1 : _editingGender == '女' ? 2 : 0;
            break;
          case '生日':
            updateData['birthday'] = _editingBirthday?.toIso8601String();
            break;
        }
        
        // 更新数据库中的用户信息
        final userDatabase = UserDatabaseService();
        
        // 个人信息字段应该更新到扩展表，不是主表
        // 对于买家用户，昵称、真实姓名、邮箱、手机号等字段在buyer_extensions表中
        await userDatabase.updateUser(
          userId,
          {},
          updateData,
        );
        
        // 重新加载用户信息
        if (mounted) {
          context.read<SecurityBloc>().add(LoadSecuritySettings());
          
          // 更新本地状态变量，确保UI立即刷新
          if (field == '真实姓名') {
            setState(() {
              _displayRealName = _realNameController.text;
            });
          } else if (field == '手机号') {
            setState(() {
              _displayPhone = _phoneController.text;
            });
          } else if (field == '性别') {
            setState(() {
              _displayGender = _editingGender;
            });
          } else if (field == '生日') {
            setState(() {
              _displayBirthday = _editingBirthday;
            });
          } else if (field == '邮箱') {
            // 更新会话中的邮箱，确保下次登录时使用新邮箱
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_email', _emailController.text);
          }
          
          // 退出编辑模式
          setState(() {
            _editingField = null;
          });
          
          // 显示成功提示
          _showSuccess('用户信息更新成功');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('更新用户信息失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}

// 相机预览页面，用于Windows平台
class CameraPreviewPage extends StatefulWidget {
  const CameraPreviewPage({super.key});

  @override
  _CameraPreviewPageState createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isTakingPicture = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
    });
    
    try {
      // 获取可用摄像头
      final cameras = await availableCameras();
      if (!mounted) return;
      
      if (cameras.isEmpty) {
        throw Exception('没有可用的摄像头');
      }
      
      // 使用第一个摄像头
      final firstCamera = cameras.first;
      
      // 创建控制器
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
      );
      
      // 初始化控制器
      _initializeControllerFuture = _controller!.initialize();
      
      // 等待初始化完成
      await _initializeControllerFuture;
    } catch (e) {
      print('初始化相机失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化相机失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 释放控制器
    _controller?.dispose();
    super.dispose();
  }

  // 拍摄照片
  Future<void> _takePicture() async {
    try {
      if (_controller == null) {
        throw Exception('相机控制器未初始化');
      }
      
      setState(() {
        _isTakingPicture = true;
      });
      
      // 确保控制器已初始化
      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      } else {
        throw Exception('相机初始化未完成');
      }
      
      // 拍摄照片
      final image = await _controller!.takePicture();
      
      // 关闭页面并返回照片路径
      Navigator.pop(context, image.path);
    } catch (e) {
      print('拍摄照片失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍摄照片失败: $e')),
      );
      setState(() {
        _isTakingPicture = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('相机预览'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // 相机预览
          if (_isInitializing)
            Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          else if (_controller != null && _initializeControllerFuture != null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // 初始化完成，显示预览
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '初始化相机失败: ${snapshot.error}',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return CameraPreview(_controller!);
                } else {
                  // 初始化中，显示加载指示器
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  );
                }
              },
            )
          else
            Center(
              child: Text(
                '无法初始化相机',
                style: TextStyle(color: Colors.white),
              ),
            ),
          // 底部控制栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 按钮行：取消和拍照
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 取消按钮
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      
                      // 拍摄按钮
                      GestureDetector(
                        onTap: (_isTakingPicture || _isInitializing || _controller == null) ? null : _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isTakingPicture || _isInitializing || _controller == null) ? Colors.grey : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // 占位按钮，保持布局平衡
                      Container(
                        width: 60,
                        height: 60,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击拍照',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 加载指示器
          if (_isTakingPicture)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


