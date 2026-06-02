import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 地址编辑页面，用于添加和编辑收货地址
class AddressEditPage extends ConsumerStatefulWidget {
  // 编辑模式下传入的地址数据，null表示添加新地址
  final Map<String, dynamic>? address;
  
  const AddressEditPage({super.key, this.address});

  @override
  ConsumerState<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends ConsumerState<AddressEditPage> {
  // 表单控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  
  // 表单验证状态
  String? _nameError;
  String? _phoneError;
  String? _provinceError;
  String? _cityError;
  String? _districtError;
  String? _detailError;
  
  // 默认地址复选框状态
  bool _isDefault = false;
  
  @override
  void initState() {
    super.initState();
    
    // 如果是编辑模式，填充现有数据
    if (widget.address != null) {
      final address = widget.address!;
      _nameController.text = address['name'] ?? '';
      _phoneController.text = address['phone'] ?? '';
      _provinceController.text = address['province'] ?? '';
      _cityController.text = address['city'] ?? '';
      _districtController.text = address['district'] ?? '';
      _detailController.text = address['detail'] ?? '';
      _isDefault = address['isDefault'] ?? false;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _detailController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final isEditMode = widget.address != null;
    
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
          isEditMode ? '编辑地址' : '添加新地址',
          style: TextStyle(color: theme.colorScheme.onBackground),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 收货人姓名
            _buildInputField(
              controller: _nameController,
              label: '收货人姓名',
              hintText: '请输入收货人姓名',
              errorText: _nameError,
              onChanged: (value) {
                if (_nameError != null) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 20),
            
            // 手机号码
            _buildInputField(
              controller: _phoneController,
              label: '手机号码',
              hintText: '请输入手机号码',
              errorText: _phoneError,
              onChanged: (value) {
                if (_phoneError != null) {
                  setState(() {
                    _phoneError = null;
                  });
                }
              },
              keyboardType: TextInputType.phone,
              theme: theme,
            ),
            const SizedBox(height: 20),
            
            // 省份
            _buildInputField(
              controller: _provinceController,
              label: '省份',
              hintText: '请输入省份',
              errorText: _provinceError,
              onChanged: (value) {
                if (_provinceError != null) {
                  setState(() {
                    _provinceError = null;
                  });
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 20),
            
            // 城市
            _buildInputField(
              controller: _cityController,
              label: '城市',
              hintText: '请输入城市',
              errorText: _cityError,
              onChanged: (value) {
                if (_cityError != null) {
                  setState(() {
                    _cityError = null;
                  });
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 20),
            
            // 区县
            _buildInputField(
              controller: _districtController,
              label: '区县',
              hintText: '请输入区县',
              errorText: _districtError,
              onChanged: (value) {
                if (_districtError != null) {
                  setState(() {
                    _districtError = null;
                  });
                }
              },
              theme: theme,
            ),
            const SizedBox(height: 20),
            
            // 详细地址
            _buildInputField(
              controller: _detailController,
              label: '详细地址',
              hintText: '请输入详细地址',
              errorText: _detailError,
              onChanged: (value) {
                if (_detailError != null) {
                  setState(() {
                    _detailError = null;
                  });
                }
              },
              maxLines: 3,
              theme: theme,
            ),
            const SizedBox(height: 24),
            
            // 默认地址复选框
            _buildDefaultCheckbox(theme),
            const SizedBox(height: 40),
            
            // 保存按钮
            _buildSaveButton(theme, isEditMode),
          ],
        ),
      ),
    );
  }
  
  // 构建输入字段
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? errorText,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
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
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              errorText: errorText,
              errorStyle: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建默认地址复选框
  Widget _buildDefaultCheckbox(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '设为默认地址',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        Switch(
          value: _isDefault,
          onChanged: (value) {
            setState(() {
              _isDefault = value;
            });
          },
          activeColor: theme.colorScheme.primary,
          activeTrackColor: theme.colorScheme.primary.withOpacity(0.3),
          inactiveThumbColor: theme.colorScheme.onSurfaceVariant,
          inactiveTrackColor: theme.colorScheme.outlineVariant,
        ),
      ],
    );
  }
  
  // 构建保存按钮
  Widget _buildSaveButton(ThemeData theme, bool isEditMode) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saveAddress,
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
        child: Text(
          isEditMode ? '保存修改' : '保存地址',
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }
  
  // 验证表单
  bool _validateForm() {
    bool isValid = true;
    
    // 验证收货人姓名
    if (_nameController.text.isEmpty) {
      setState(() {
        _nameError = '请输入收货人姓名';
      });
      isValid = false;
    }
    
    // 验证手机号码
    if (_phoneController.text.isEmpty) {
      setState(() {
        _phoneError = '请输入手机号码';
      });
      isValid = false;
    } else if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text)) {
      setState(() {
        _phoneError = '请输入有效的手机号码';
      });
      isValid = false;
    }
    
    // 验证省份
    if (_provinceController.text.isEmpty) {
      setState(() {
        _provinceError = '请输入省份';
      });
      isValid = false;
    }
    
    // 验证城市
    if (_cityController.text.isEmpty) {
      setState(() {
        _cityError = '请输入城市';
      });
      isValid = false;
    }
    
    // 验证区县
    if (_districtController.text.isEmpty) {
      setState(() {
        _districtError = '请输入区县';
      });
      isValid = false;
    }
    
    // 验证详细地址
    if (_detailController.text.isEmpty) {
      setState(() {
        _detailError = '请输入详细地址';
      });
      isValid = false;
    }
    
    return isValid;
  }
  
  // 保存地址
  void _saveAddress() {
    if (!_validateForm()) {
      return;
    }
    
    final newAddress = {
      'id': widget.address != null ? widget.address!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameController.text,
      'phone': _phoneController.text,
      'province': _provinceController.text,
      'city': _cityController.text,
      'district': _districtController.text,
      'detail': _detailController.text,
      'isDefault': _isDefault,
    };
    
    // 返回结果给上一页
    Navigator.pop(context, newAddress);
  }
}