import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';

/// 售后申请页面
class AfterSalesApplyPage extends StatefulWidget {
  /// 构造函数
  const AfterSalesApplyPage({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.variant,
    required this.quantity,
    required this.amount,
  });

  /// 订单ID
  final String orderId;
  /// 商品ID
  final String productId;
  /// 商品名称
  final String productName;
  /// 商品图片
  final String productImage;
  /// 商品规格
  final String variant;
  /// 商品数量
  final int quantity;
  /// 商品金额
  final double amount;

  @override
  State<AfterSalesApplyPage> createState() => _AfterSalesApplyPageState();
}

class _AfterSalesApplyPageState extends State<AfterSalesApplyPage> {
  /// 售后类型
  String _afterSalesType = 'refund';
  /// 申请原因
  String _reason = 'quality';
  /// 问题描述
  final TextEditingController _descriptionController = TextEditingController();
  /// 选中的图片列表
  List<XFile> _selectedImages = [];
  /// 是否正在提交
  bool _isSubmitting = false;
  
  /// 物流信息（仅退款退货需要）
  final TextEditingController _logisticsCompanyController = TextEditingController();
  final TextEditingController _trackingNumberController = TextEditingController();
  
  /// 存储服务实例
  final StorageService _storageService = StorageService();

  @override
  void dispose() {
    _descriptionController.dispose();
    _logisticsCompanyController.dispose();
    _trackingNumberController.dispose();
    super.dispose();
  }

  /// 选择图片
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedImages = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedImages.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedImages);
      });
    }
  }

  /// 删除选中的图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// 提交售后申请
  Future<void> _submitAfterSalesApply() async {
    setState(() {
      _isSubmitting = true;
    });

    // 模拟网络请求延迟
    await Future.delayed(const Duration(seconds: 1));

    // 检查问题描述是否为空
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('问题描述不能为空'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }
    
    // 检查物流信息（仅退款退货需要）
    if (_afterSalesType == 'returnGoods') {
      final logisticsCompany = _logisticsCompanyController.text.trim();
      final trackingNumber = _trackingNumberController.text.trim();
      
      if (logisticsCompany.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('物流公司不能为空'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
      
      if (trackingNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('物流单号不能为空'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
    }

    // 创建售后申请通知
    final notification = NotificationInfo(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      orderId: widget.orderId,
      productName: widget.productName,
      productImage: widget.productImage,
      type: NotificationType.applyAfterSales,
      content: '客户已提交售后申请，订单号: ${widget.orderId}',
      createdAt: DateTime.now(),
    );
    
    // 保存通知到数据库
    await NotificationDatabaseService().addNotification(notification);
    
    // 根据售后类型更新订单状态
    final databaseService = DatabaseService();
    String orderStatus;
    switch (_afterSalesType) {
      case 'refund':
      case 'returnGoods':
        orderStatus = '退款中';
        break;
      case 'repair':
        orderStatus = '维修中';
        break;
      default:
        orderStatus = '退款中';
    }
    
    // 更新订单状态和售后信息
    await databaseService.updateOrderStatus(widget.orderId, orderStatus);
    
    // 保存售后图片到指定目录
    List<String> imageNames = [];
    for (var image in _selectedImages) {
      // 从订单ID中提取用户ID
      final userId = widget.orderId.split('_')[0];
      
      // 存储图片到指定目录
      final storedPath = await _storageService.storeFile(
        image,
        fileType: 'after-sales', // 指定为售后文件类型
        userId: userId,
        isStore: true, // 存储到store目录
      );
      
      // 只存储图片名称，不存储完整路径
      final imageName = path.basename(storedPath);
      imageNames.add(imageName);
    }
    
    // 保存售后具体信息到订单表
    final afterSalesData = {
      'after_sales_type': _afterSalesType,
      'after_sales_reason': _reason,
      'after_sales_description': description,
      'after_sales_create_time': DateTime.now().millisecondsSinceEpoch,
      'after_sales_status': orderStatus,
      // 将图片名称列表转换为JSON字符串存储
      'after_sales_images': jsonEncode(imageNames),
    };
    await databaseService.updateOrder(widget.orderId, afterSalesData);

    // 模拟提交售后申请成功
    debugPrint('提交售后申请成功：');
    debugPrint('售后类型：$_afterSalesType');
    debugPrint('申请原因：$_reason');
    debugPrint('问题描述：$description');
    debugPrint('图片数量：${_selectedImages.length}');
    // 仅退款退货显示物流信息
    if (_afterSalesType == 'returnGoods') {
      debugPrint('物流公司：${_logisticsCompanyController.text.trim()}');
      debugPrint('物流单号：${_trackingNumberController.text.trim()}');
    }
    debugPrint('订单状态已更新为${_afterSalesType == 'repair' ? '维修中' : '退款中'}');

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('售后申请提交成功'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    // 延迟一段时间，让用户看到成功提示后再返回
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // 返回上一页，并传递刷新信号
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '申请售后',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceVariant,
                    ),
                    child: widget.productImage.startsWith('http')
                        ? Image.network(
                            widget.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          )
                        : Image.file(
                            File(widget.productImage),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.productName,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.variant,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'x${widget.quantity}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '¥${widget.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 24),

            // 售后类型
            Text(
              '售后类型',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildRadioItem('refund', '仅退款', _afterSalesType),
                  _buildDivider(),
                  _buildRadioItem('returnGoods', '退货退款', _afterSalesType),
                  _buildDivider(),
                  _buildRadioItem('repair', '维修', _afterSalesType),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 申请原因
            Text(
              '申请原因',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildRadioItem('quality', '商品质量问题', _reason),
                  _buildDivider(),
                  _buildRadioItem('wrongProduct', '发错商品', _reason),
                  _buildDivider(),
                  _buildRadioItem('size', '尺码不合适', _reason),
                  _buildDivider(),
                  _buildRadioItem('notAsDescribed', '与描述不符', _reason),
                  _buildDivider(),
                  _buildRadioItem('other', '其他原因', _reason),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 问题描述
            Text(
              '问题描述',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 6,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '请详细描述您遇到的问题',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 上传图片
            Text(
              '上传图片',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 添加图片按钮
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 32,
                    ),
                  ),
                ),
                // 已选择的图片
                ..._selectedImages.map((image) => Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceVariant,
                          ),
                          child: Image.file(
                            File(image.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        // 删除按钮
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _removeImage(_selectedImages.indexOf(image));
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '最多可上传5张图片',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            
            // 物流信息（仅退款退货需要）
            if (_afterSalesType == 'returnGoods') ...[
              Text(
                '物流信息',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // 物流公司输入
                      TextField(
                        controller: _logisticsCompanyController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: '物流公司',
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 物流单号输入
                      TextField(
                        controller: _trackingNumberController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: '物流单号',
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAfterSalesApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
                    : const Text('提交申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单选按钮项
  Widget _buildRadioItem(String value, String label, String groupValue) {
    // 判断当前是售后类型选择还是申请原因选择
    final isAfterSalesType = groupValue == 'refund' || groupValue == 'returnGoods' || groupValue == 'repair';
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isAfterSalesType) {
            _afterSalesType = value;
          } else {
            _reason = value;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: isAfterSalesType ? _afterSalesType : _reason,
              onChanged: (String? newValue) {
                setState(() {
                  if (isAfterSalesType) {
                    _afterSalesType = newValue!;
                  } else {
                    _reason = newValue!;
                  }
                });
              },
              activeColor: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分隔线
  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Container(
      height: 1,
      color: theme.colorScheme.outline.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}