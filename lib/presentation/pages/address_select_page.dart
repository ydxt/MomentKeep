import 'package:flutter/material.dart';

/// 地址信息模型
class AddressInfo {
  final String id;
  final String name;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final bool isDefault;

  AddressInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
    this.isDefault = false,
  });

  /// 获取完整地址
  String get fullAddress {
    return '$province$city$district$detailAddress';
  }

  /// 从Map转换为AddressInfo对象
  factory AddressInfo.fromMap(Map<String, dynamic> map) {
    return AddressInfo(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      detailAddress: map['detail_address'] ?? '',
      isDefault: (map['is_default'] ?? 0) == 1,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'province': province,
      'city': city,
      'district': district,
      'detail_address': detailAddress,
      'is_default': isDefault ? 1 : 0,
    };
  }
}

/// 地址选择页面
class AddressSelectPage extends StatefulWidget {
  /// 当前选中的地址ID
  final String? selectedAddressId;

  /// 构造函数
  const AddressSelectPage({
    super.key,
    this.selectedAddressId,
  });

  @override
  State<AddressSelectPage> createState() => _AddressSelectPageState();
}

class _AddressSelectPageState extends State<AddressSelectPage> {
  List<AddressInfo> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  /// 加载地址列表
  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 模拟从数据库加载地址数据
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _addresses = [
          AddressInfo(
            id: '1',
            name: '张三',
            phone: '13800138000',
            province: '广东省',
            city: '深圳市',
            district: '南山区',
            detailAddress: '科技园路1号A座1001室',
            isDefault: true,
          ),
          AddressInfo(
            id: '2',
            name: '李四',
            phone: '13900139000',
            province: '北京市',
            city: '朝阳区',
            district: '建国路',
            detailAddress: '100号华贸中心',
            isDefault: false,
          ),
          AddressInfo(
            id: '3',
            name: '王五',
            phone: '13700137000',
            province: '上海市',
            city: '浦东新区',
            district: '陆家嘴',
            detailAddress: '金融贸易区88号',
            isDefault: false,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 选择地址
  void _selectAddress(AddressInfo address) {
    Navigator.pop(context, address);
  }

  /// 添加新地址
  void _addNewAddress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a3525),
      isScrollControlled: true,
      builder: (context) => const AddAddressSheet(),
    ).then((value) {
      if (value == true) {
        _loadAddresses();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF112217),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112217),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '选择收货地址',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addNewAddress,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF13ec5b)),
            )
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        color: Color(0xFF92c9a4),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收货地址',
                        style: TextStyle(
                          color: const Color(0xFF92c9a4).withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addNewAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13ec5b),
                          foregroundColor: const Color(0xFF112217),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('添加新地址'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    final isSelected = widget.selectedAddressId == address.id;
                    return _buildAddressItem(address, isSelected);
                  },
                ),
    );
  }

  /// 构建地址项
  Widget _buildAddressItem(AddressInfo address, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectAddress(address),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a3525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF13ec5b)
                : const Color(0xFF326744).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：姓名、电话、标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      address.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      address.phone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (address.isDefault)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13ec5b).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '默认',
                      style: TextStyle(
                        color: Color(0xFF13ec5b),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 地址详情
            Text(
              address.fullAddress,
              style: const TextStyle(
                color: Color(0xFF92c9a4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // 编辑地址
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF1a3525),
                      isScrollControlled: true,
                      builder: (context) => AddAddressSheet(
                        address: address,
                      ),
                    ).then((value) {
                      if (value == true) {
                        _loadAddresses();
                      }
                    });
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: Color(0xFF92c9a4),
                    size: 16,
                  ),
                  label: Text(
                    '编辑',
                    style: const TextStyle(color: Color(0xFF92c9a4)),
                  ),
                ),
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: () {
                      // 设置为默认地址
                      setState(() {
                        _addresses = _addresses.map((addr) {
                          if (addr.id == address.id) {
                            return AddressInfo(
                              id: addr.id,
                              name: addr.name,
                              phone: addr.phone,
                              province: addr.province,
                              city: addr.city,
                              district: addr.district,
                              detailAddress: addr.detailAddress,
                              isDefault: true,
                            );
                          }
                          return AddressInfo(
                            id: addr.id,
                            name: addr.name,
                            phone: addr.phone,
                            province: addr.province,
                            city: addr.city,
                            district: addr.district,
                            detailAddress: addr.detailAddress,
                            isDefault: false,
                          );
                        }).toList();
                      });
                    },
                    icon: const Icon(
                      Icons.star_border,
                      color: Color(0xFF92c9a4),
                      size: 16,
                    ),
                    label: Text(
                      '设为默认',
                      style: const TextStyle(color: Color(0xFF92c9a4)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加/编辑地址页面
class AddAddressSheet extends StatefulWidget {
  /// 要编辑的地址（可选）
  final AddressInfo? address;

  /// 构造函数
  const AddAddressSheet({
    super.key,
    this.address,
  });

  @override
  State<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<AddAddressSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _nameController.text = widget.address!.name;
      _phoneController.text = widget.address!.phone;
      _provinceController.text = widget.address!.province;
      _cityController.text = widget.address!.city;
      _districtController.text = widget.address!.district;
      _detailController.text = widget.address!.detailAddress;
      _isDefault = widget.address!.isDefault;
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

  /// 保存地址
  Future<void> _saveAddress() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final province = _provinceController.text.trim();
    final city = _cityController.text.trim();
    final district = _districtController.text.trim();
    final detail = _detailController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        province.isEmpty ||
        city.isEmpty ||
        district.isEmpty ||
        detail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写完整的地址信息'),
          backgroundColor: Color(0xFFff4757),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // 模拟保存延迟
    await Future.delayed(const Duration(seconds: 1));

    // 返回成功结果
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1a3525),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部操作栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.address != null ? '编辑地址' : '添加新地址',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 姓名
            _buildTextField(
              controller: _nameController,
              label: '收货人姓名',
              hint: '请输入收货人姓名',
            ),
            const SizedBox(height: 16),
            // 电话
            _buildTextField(
              controller: _phoneController,
              label: '联系电话',
              hint: '请输入联系电话',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // 省份
            _buildTextField(
              controller: _provinceController,
              label: '省份',
              hint: '请输入省份',
            ),
            const SizedBox(height: 16),
            // 城市
            _buildTextField(
              controller: _cityController,
              label: '城市',
              hint: '请输入城市',
            ),
            const SizedBox(height: 16),
            // 区县
            _buildTextField(
              controller: _districtController,
              label: '区县',
              hint: '请输入区县',
            ),
            const SizedBox(height: 16),
            // 详细地址
            _buildTextField(
              controller: _detailController,
              label: '详细地址',
              hint: '请输入详细地址',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 设为默认地址
            Row(
              children: [
                Checkbox(
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF13ec5b),
                ),
                const SizedBox(width: 8),
                const Text(
                  '设为默认地址',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13ec5b),
                  foregroundColor: const Color(0xFF112217),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Color(0xFF112217))
                    : const Text('保存地址'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF92c9a4)),
            filled: true,
            fillColor: const Color(0xFF112217),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF326744)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF326744)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF13ec5b)),
            ),
          ),
        ),
      ],
    );
  }
}
