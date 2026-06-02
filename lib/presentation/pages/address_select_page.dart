import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/database_service.dart';

class AddressSelectPage extends StatefulWidget {
  final int? selectedAddressId;

  const AddressSelectPage({
    super.key,
    this.selectedAddressId,
  });

  @override
  State<AddressSelectPage> createState() => _AddressSelectPageState();
}

class _AddressSelectPageState extends State<AddressSelectPage> {
  List<Address> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await DatabaseService().getCurrentUserId() ?? 'default_user';
      final db = ProductDatabaseService();
      final addresses = await db.getUserAddresses(userId);
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      if (mounted) {
        setState(() {
          _error = '加载地址失败，请重试';
          _isLoading = false;
        });
      }
    }
  }

  void _selectAddress(Address address) {
    Navigator.pop(context, address);
  }

  void _addNewAddress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a3525),
      isScrollControlled: true,
      builder: (context) => const _AddressFormSheet(),
    ).then((value) {
      if (value == true) {
        _loadAddresses();
      }
    });
  }

  void _editAddress(Address address) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a3525),
      isScrollControlled: true,
      builder: (context) => _AddressFormSheet(address: address),
    ).then((value) {
      if (value == true) {
        _loadAddresses();
      }
    });
  }

  Future<void> _setDefaultAddress(Address address) async {
    try {
      final userId = await DatabaseService().getCurrentUserId() ?? 'default_user';
      final db = ProductDatabaseService();
      await db.setDefaultAddress(address.id!, userId);
      _loadAddresses();
    } catch (e) {
      debugPrint('Error setting default address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置默认地址失败'),
            backgroundColor: Color(0xFFff4757),
          ),
        );
      }
    }
  }

  void _deleteAddress(Address address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a3525),
        title: const Text(
          '确认删除',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '确定要删除该收货地址吗？',
          style: TextStyle(color: Color(0xFF92c9a4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF92c9a4)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(address);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFff4757),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Address address) async {
    try {
      final db = ProductDatabaseService();
      await db.deleteAddress(address.id!);
      _loadAddresses();
    } catch (e) {
      debugPrint('Error deleting address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除地址失败'),
            backgroundColor: Color(0xFFff4757),
          ),
        );
      }
    }
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
          : _error != null
              ? _buildErrorState()
              : _addresses.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _addresses.length,
                      itemBuilder: (context, index) {
                        final address = _addresses[index];
                        final isSelected =
                            widget.selectedAddressId == address.id;
                        return _buildAddressItem(address, isSelected);
                      },
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFF92c9a4),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFF92c9a4),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAddresses,
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
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            child: const Text('添加地址'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressItem(Address address, bool isSelected) {
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
            Text(
              address.fullAddress,
              style: const TextStyle(
                color: Color(0xFF92c9a4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editAddress(address),
                  icon: const Icon(
                    Icons.edit,
                    color: Color(0xFF92c9a4),
                    size: 16,
                  ),
                  label: const Text(
                    '编辑',
                    style: TextStyle(color: Color(0xFF92c9a4)),
                  ),
                ),
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: () => _setDefaultAddress(address),
                    icon: const Icon(
                      Icons.star_border,
                      color: Color(0xFF92c9a4),
                      size: 16,
                    ),
                    label: const Text(
                      '设为默认',
                      style: TextStyle(color: Color(0xFF92c9a4)),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _deleteAddress(address),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFff4757),
                    size: 16,
                  ),
                  label: const Text(
                    '删除',
                    style: TextStyle(color: Color(0xFFff4757)),
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

class _AddressFormSheet extends StatefulWidget {
  final Address? address;

  const _AddressFormSheet({
    this.address,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
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
      _detailController.text = widget.address!.detail;
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

    try {
      final userId =
          await DatabaseService().getCurrentUserId() ?? 'default_user';
      final db = ProductDatabaseService();
      final now = DateTime.now();

      if (widget.address != null) {
        final updatedAddress = Address(
          id: widget.address!.id,
          userId: userId,
          name: name,
          phone: phone,
          province: province,
          city: city,
          district: district,
          detail: detail,
          isDefault: _isDefault,
          createdAt: widget.address!.createdAt,
          updatedAt: now,
        );
        await db.updateAddress(widget.address!.id!, updatedAddress);
      } else {
        final newAddress = Address(
          userId: userId,
          name: name,
          phone: phone,
          province: province,
          city: city,
          district: district,
          detail: detail,
          isDefault: _isDefault,
          createdAt: now,
          updatedAt: now,
        );
        await db.insertAddress(newAddress);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving address: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存地址失败，请重试'),
            backgroundColor: Color(0xFFff4757),
          ),
        );
      }
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
            _buildTextField(
              controller: _nameController,
              label: '收货人姓名',
              hint: '请输入收货人姓名',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: '联系电话',
              hint: '请输入联系电话',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _provinceController,
              label: '省份',
              hint: '请输入省份',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cityController,
              label: '城市',
              hint: '请输入城市',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _districtController,
              label: '区县',
              hint: '请输入区县',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _detailController,
              label: '详细地址',
              hint: '请输入详细地址',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
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
                    ? const CircularProgressIndicator(
                        color: Color(0xFF112217))
                    : const Text('保存地址'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
