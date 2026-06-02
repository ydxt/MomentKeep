import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';
import 'package:moment_keep/presentation/pages/address_edit_page.dart';

class ShippingAddressPage extends ConsumerStatefulWidget {
  const ShippingAddressPage({super.key});

  @override
  ConsumerState<ShippingAddressPage> createState() => _ShippingAddressPageState();
}

class _ShippingAddressPageState extends ConsumerState<ShippingAddressPage> {
  // 模拟收货地址数据
  List<Map<String, dynamic>> _addresses = [
    {
      'id': '1',
      'name': '张三',
      'phone': '13812345678',
      'province': '广东省',
      'city': '深圳市',
      'district': '南山区',
      'detail': '科技园南区XX号XX栋XX室',
      'isDefault': true,
    },
    {
      'id': '2',
      'name': '李四',
      'phone': '13987654321',
      'province': '北京市',
      'city': '北京市',
      'district': '海淀区',
      'detail': '中关村大街XX号XX大厦XX层',
      'isDefault': false,
    },
  ];

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
        title: Text('收货地址管理', style: TextStyle(color: theme.colorScheme.onBackground)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 地址列表
          Expanded(
            child: _addresses.isEmpty
                ? _buildEmptyAddress(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final address = _addresses[index];
                      return _buildAddressItem(address, theme);
                    },
                  ),
          ),
          
          // 添加新地址按钮
          _buildAddAddressButton(theme),
        ],
      ),
    );
  }

  // 构建空地址状态
  Widget _buildEmptyAddress(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            color: theme.colorScheme.onSurfaceVariant,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无收货地址',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _addAddress();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('添加收货地址', style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  // 构建地址项
  Widget _buildAddressItem(Map<String, dynamic> address, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 收货人信息和默认标记
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    address['name'],
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    address['phone'],
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (address['isDefault']) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '默认',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 地址信息
          Text(
            '${address['province']}${address['city']}${address['district']}${address['detail']}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!address['isDefault']) 
                TextButton(
                  onPressed: () {
                    _updateDefaultAddress(address['id']);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text('设为默认'),
                ),
              TextButton(
                onPressed: () {
                  _editAddress(address);
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('编辑'),
              ),
              TextButton(
                onPressed: () {
                  _deleteAddress(address['id']);
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建添加新地址按钮
  Widget _buildAddAddressButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            _addAddress();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          child: Text('添加新地址', style: TextStyle(color: theme.colorScheme.onPrimary)),
        ),
      ),
    );
  }

  // 编辑地址
  void _editAddress(Map<String, dynamic> address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressEditPage(address: address),
      ),
    );
    
    if (result != null) {
      setState(() {
        // 更新地址列表
        final index = _addresses.indexWhere((item) => item['id'] == address['id']);
        if (index != -1) {
          _addresses[index] = result as Map<String, dynamic>;
          
          // 如果设置了默认地址，将其他地址的默认状态取消
          if (result['isDefault']) {
            _updateDefaultAddress(result['id']);
          }
        }
      });
      
      final theme = ref.watch(currentThemeProvider);
      _showSuccess('地址更新成功', theme);
    }
  }

  // 添加新地址
  void _addAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressEditPage(),
      ),
    );
    
    if (result != null) {
      setState(() {
        final newAddress = result as Map<String, dynamic>;
        _addresses.add(newAddress);
        
        // 如果设置了默认地址，将其他地址的默认状态取消
        if (newAddress['isDefault']) {
          _updateDefaultAddress(newAddress['id']);
        }
      });
      
      final theme = ref.watch(currentThemeProvider);
      _showSuccess('地址添加成功', theme);
    }
  }

  // 删除地址
  void _deleteAddress(String addressId) {
    final theme = ref.watch(currentThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceVariant,
        title: Text(
          '确认删除',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          '确定要删除该收货地址吗？',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _addresses.removeWhere((address) => address['id'] == addressId);
              });
              _showSuccess('地址删除成功', theme);
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text('删除', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  // 更新默认地址
  void _updateDefaultAddress(String addressId) {
    setState(() {
      for (var address in _addresses) {
        address['isDefault'] = address['id'] == addressId;
      }
    });
  }

  // 显示成功提示
  void _showSuccess(String message, ThemeData theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
