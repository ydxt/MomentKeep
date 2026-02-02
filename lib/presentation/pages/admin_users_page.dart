import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/utils/encryption_helper.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 管理员用户管理页面
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// 加载所有用户
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _databaseService.getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载用户列表失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 删除用户
  Future<void> _deleteUser(String userId, String username) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 "$username" 吗？这将删除该用户的所有数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _databaseService.deleteUser(userId);
        if (result > 0) {
          // 重新加载用户列表
          _loadUsers();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户删除成功')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除用户失败')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除用户失败: $e')),
        );
      }
    }
  }

  /// 切换用户管理员权限
  Future<void> _toggleAdminStatus(String userId, bool isAdmin) async {
    try {
      final result = await _databaseService.setUserAdminStatus(userId, !isAdmin);
      if (result > 0) {
        // 重新加载用户列表
        _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAdmin ? '已撤销管理员权限' : '已授予管理员权限')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新管理员权限失败')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新管理员权限失败: $e')),
      );
    }
  }

  /// 显示用户详情对话框
  void _showUserDetails(Map<String, dynamic> user) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('用户详情: ${user['username']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('ID'),
                subtitle: Text(user['id']),
                dense: true,
              ),
              ListTile(
                title: const Text('用户名'),
                subtitle: Text(user['username']),
                dense: true,
              ),
              ListTile(
                title: const Text('邮箱'),
                subtitle: Text(user['email']),
                dense: true,
              ),
              ListTile(
                title: const Text('创建时间'),
                subtitle: Text(_formatDateTime(user['created_at'])),
                dense: true,
              ),
              ListTile(
                title: const Text('上次登录'),
                subtitle: Text(user['last_login_at'] != null ? _formatDateTime(user['last_login_at']) : '从未登录'),
                dense: true,
              ),
              ListTile(
                title: const Text('邮箱验证状态'),
                subtitle: Text(user['is_email_verified'] == 1 ? '已验证' : '未验证'),
                dense: true,
              ),
              ListTile(
                title: const Text('管理员状态'),
                subtitle: Text(user['is_admin'] == 1 ? '是' : '否'),
                dense: true,
              ),
              if (user['avatar_url'] != null)
                ListTile(
                  title: const Text('头像路径'),
                  subtitle: Text(user['avatar_url']),
                  dense: true,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.tryParse(dateTimeString);
    if (dateTime == null) return dateTimeString;
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }



  /// 显示创建用户对话框
  void _showCreateUserDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    ).then((value) {
      if (value == true) {
        // 重新加载用户列表
        _loadUsers();
      }
    });
  }

  /// 显示用户数据管理对话框
  void _showManageUserDataDialog(Map<String, dynamic> user) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _ManageUserDataDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: '刷新用户列表',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('暂无用户数据', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isAdmin = user['is_admin'] == 1;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 用户基本信息行
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['username'],
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user['email'],
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '管理员',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 用户详情行
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDateTime(user['created_at']),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  user['last_login_at'] != null ? _formatDateTime(user['last_login_at']) : '从未登录',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 操作按钮行
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () => _showUserDetails(user),
                                  tooltip: '查看详情',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.data_array),
                                  onPressed: () => _showManageUserDataDialog(user),
                                  tooltip: '管理用户数据',
                                ),
                                Switch(
                                  value: isAdmin,
                                  onChanged: (value) => _toggleAdminStatus(user['id'], isAdmin),
                                  activeColor: Colors.red,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteUser(user['id'], user['username']),
                                  tooltip: '删除用户',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        tooltip: '创建新用户',
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 创建用户对话框
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAdmin = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 生成随机用户ID
  String _generateUserId() {
    final random = Random();
    return random.nextInt(1000000).toString().padLeft(6, '0');
  }

  /// 生成密码哈希
  Future<String> _hashPassword(String password) async {
    // 使用EncryptionHelper进行密码加密
    return await EncryptionHelper.encrypt(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建新用户'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '请输入用户名',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  hintText: '请输入邮箱',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入邮箱';
                  }
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                    return '请输入有效的邮箱地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (value.length < 6) {
                    return '密码长度不能少于6个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('设置为管理员'),
                value: _isAdmin,
                onChanged: (value) {
                  setState(() {
                    _isAdmin = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              // 关闭对话框并返回创建成功
              Navigator.pop(context, true);
              
              try {
                final db = await DatabaseService().database;
                final now = DateTime.now().toIso8601String();
                final userId = _generateUserId();
                final passwordHash = await _hashPassword(_passwordController.text);
                
                final userMap = {
                  'id': userId,
                  'username': _usernameController.text,
                  'email': _emailController.text,
                  'password_hash': passwordHash,
                  'is_admin': _isAdmin ? 1 : 0,
                  'created_at': now,
                  'last_login_at': now,
                  'is_email_verified': 1,
                };
                
                await db.insert('users', userMap);
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('用户创建成功')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('创建用户失败: $e')),
                );
              }
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('创建'),
        ),
      ],
    );
  }
}

/// 管理用户数据对话框
class _ManageUserDataDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const _ManageUserDataDialog({required this.user});

  @override
  State<_ManageUserDataDialog> createState() => _ManageUserDataDialogState();
}

class _ManageUserDataDialogState extends State<_ManageUserDataDialog> {
  final DatabaseService _databaseService = DatabaseService();
  int _habitCount = 0;
  int _todoCount = 0;
  int _journalCount = 0;
  int _pomodoroCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 加载用户数据统计
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _databaseService.database;
      final userId = widget.user['id'];

      // 获取习惯数量
      final habitResult = await db.rawQuery(
        'SELECT COUNT(*) FROM habits WHERE user_id = ?',
        [userId],
      );
      _habitCount = habitResult.first.values.first as int;

      // 获取待办事项数量
      final todoResult = await db.rawQuery(
        'SELECT COUNT(*) FROM todos WHERE user_id = ?',
        [userId],
      );
      _todoCount = todoResult.first.values.first as int;

      // 获取日记数量
      final journalResult = await db.rawQuery(
        'SELECT COUNT(*) FROM journals WHERE user_id = ?',
        [userId],
      );
      _journalCount = journalResult.first.values.first as int;

      // 获取番茄钟记录数量
      final pomodoroResult = await db.rawQuery(
        'SELECT COUNT(*) FROM pomodoro_records WHERE user_id = ?',
        [userId],
      );
      _pomodoroCount = pomodoroResult.first.values.first as int;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载用户数据失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 清除用户数据
  Future<void> _clearUserData() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除数据'),
        content: Text('确定要清除用户 "${widget.user['username']}" 的所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = await _databaseService.database;
        final userId = widget.user['id'];

        // 开始事务
        await db.execute('BEGIN TRANSACTION');

        // 清除用户的所有数据
        await db.delete('habit_records', where: 'habit_id IN (SELECT id FROM habits WHERE user_id = ?)', whereArgs: [userId]);
        await db.delete('habit_tags', where: 'habit_id IN (SELECT id FROM habits WHERE user_id = ?)', whereArgs: [userId]);
        await db.delete('plan_habits', where: 'habit_id IN (SELECT id FROM habits WHERE user_id = ?)', whereArgs: [userId]);
        await db.delete('pomodoro_records', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('habits', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('tags', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('plans', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('achievements', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('journals', where: 'user_id = ?', whereArgs: [userId]);
        await db.delete('todos', where: 'user_id = ?', whereArgs: [userId]);

        // 提交事务
        await db.execute('COMMIT');

        // 重新加载用户数据统计
        _loadUserData();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户数据清除成功')),
        );
      } catch (e) {
        // 回滚事务
        final db = await _databaseService.database;
        await db.execute('ROLLBACK');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除用户数据失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('管理用户数据: ${widget.user['username']}'),
      content: SingleChildScrollView(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('用户数据统计:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('习惯数量'),
                    subtitle: Text('${_habitCount} 个习惯'),
                    leading: const Icon(Icons.assignment),
                  ),
                  ListTile(
                    title: const Text('待办事项数量'),
                    subtitle: Text('${_todoCount} 个待办事项'),
                    leading: const Icon(Icons.task),
                  ),
                  ListTile(
                    title: const Text('日记数量'),
                    subtitle: Text('${_journalCount} 篇日记'),
                    leading: const Icon(Icons.book),
                  ),
                  ListTile(
                    title: const Text('番茄钟记录数量'),
                    subtitle: Text('${_pomodoroCount} 条记录'),
                    leading: const Icon(Icons.timer),
                  ),
                  const SizedBox(height: 24),
                  const Text('操作:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _clearUserData,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('清除所有用户数据'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '注意: 此操作将清除该用户的所有数据，包括习惯、待办事项、日记、番茄钟记录等，操作不可恢复。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
