import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/services/notification_service.dart';
import 'package:moment_keep/services/product_database_service.dart';
import 'package:moment_keep/services/user_database_service.dart';
import 'package:moment_keep/core/services/storage_service.dart';

/// 评价编辑页面
class ReviewEditPage extends StatefulWidget {
  /// 构造函数
  const ReviewEditPage({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    this.isAppend = false,
    this.originalReviewId,
  });

  /// 订单ID
  final String orderId;
  /// 商品ID
  final String productId;
  /// 商品名称
  final String productName;
  /// 商品图片
  final String productImage;
  /// 是否为追加评价
  final bool isAppend;
  /// 原始评价ID（用于追加评价）
  final String? originalReviewId;

  @override
  State<ReviewEditPage> createState() => _ReviewEditPageState();
}

class _ReviewEditPageState extends State<ReviewEditPage> {
  /// 评分（1-5星）
  int _rating = 5;
  /// 评价内容
  final TextEditingController _contentController = TextEditingController();
  /// 追加评价内容
  final TextEditingController _appendContentController = TextEditingController();
  /// 选中的图片列表
  List<File> _selectedImages = [];
  /// 是否正在提交
  bool _isSubmitting = false;
  /// 是否匿名评论
  bool _isAnonymous = true;

  @override
  void dispose() {
    _contentController.dispose();
    _appendContentController.dispose();
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
        _selectedImages.addAll(pickedImages.map((img) => File(img.path)));
      });
    }
  }

  /// 删除选中的图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// 提交评价
  Future<void> _submitReview() async {
    setState(() {
      _isSubmitting = true;
    });

    // 检查评价内容是否为空
    final content = widget.isAppend ? _appendContentController.text.trim() : _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('评价内容不能为空'),
          backgroundColor: Color(0xFFff4757),
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // 创建评价通知
    final notification = NotificationInfo(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      orderId: widget.orderId,
      productName: widget.productName,
      productImage: widget.productImage,
      type: NotificationType.review,
      content: widget.isAppend ? '客户已追加评价，订单号: ${widget.orderId}' : '客户已评价，订单号: ${widget.orderId}',
      createdAt: DateTime.now(),
    );
    
    // 保存通知到数据库
    await NotificationDatabaseService().addNotification(notification);

    // 真正提交评价到数据库
    try {
      // 使用ProductDatabaseService保存评论
      final productDatabaseService = ProductDatabaseService();
      final databaseService = DatabaseService();
      final userDatabaseService = UserDatabaseService();
      final storageService = StorageService();
      
      // 获取当前用户信息
      final userId = await databaseService.getCurrentUserId() ?? '';
      final userData = userId.isNotEmpty ? await userDatabaseService.getUserById(userId) : null;
      
      // 存储图片到正确目录
      List<String> storedImages = [];
      if (_selectedImages.isNotEmpty) {
        for (var file in _selectedImages) {
          // 使用XFile.fromData创建XFile对象
          final xFile = XFile(file.path);
          // 存储图片到default/store/comment目录下，isStore=true表示星星商店存储，isComment=true表示评论图片
          final storedPath = await storageService.storeImage(
            xFile,
            userId: userId,
            isStore: true,
            isComment: true, // 评论图片存储在comment目录下
          );
          storedImages.add(storedPath);
        }
      }
      
      // 准备评价数据
      final reviewData = {
        'order_id': widget.orderId,
        'product_id': int.tryParse(widget.productId) ?? 0, // 使用tryParse避免解析失败
        'product_name': widget.productName,
        'product_image': widget.productImage,
        'rating': _rating,
        'content': content,
        'images': storedImages.isNotEmpty ? json.encode(storedImages) : null,
        'status': 'completed',
        'is_anonymous': _isAnonymous ? 1 : 0,
        'user_id': _isAnonymous ? null : userId,
        'user_name': _isAnonymous ? null : (userData?['user_name'] ?? '用户' + userId.substring(0, 4)),
        'user_avatar': _isAnonymous ? null : userData?['avatar'],
      };
      
      // 调用addReview方法保存评论到数据库
      await productDatabaseService.addReview(reviewData);
      
      debugPrint('提交评价成功：');
      debugPrint('评分：$_rating');
      debugPrint('内容：$content');
      debugPrint('图片数量：${_selectedImages.length}');
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAppend ? '追加评价成功' : '评价成功'),
          backgroundColor: const Color(0xFF13ec5b),
        ),
      );
    } catch (e) {
      debugPrint('提交评价失败：$e');
      
      // 显示失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('提交评价失败，请重试'),
          backgroundColor: Color(0xFFff4757),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }

    // 返回上一页
    Navigator.pop(context);
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
        title: Text(
          widget.isAppend ? '追加评价' : '写评价',
          style: const TextStyle(
            color: Colors.white,
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
                color: const Color(0xFF1a3525),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF2a4532),
                    ),
                    child: widget.productImage.startsWith('http')
                        ? Image.network(
                            widget.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF92c9a4),
                              size: 24,
                            ),
                          )
                        : Image.file(
                            File(widget.productImage),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF92c9a4),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 评分
            if (!widget.isAppend) ...[
              const Text(
                '评分',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFffc107),
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
            ],

            // 评价内容
            Text(
              widget.isAppend ? '追加评价内容' : '评价内容',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a3525),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: widget.isAppend ? _appendContentController : _contentController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: widget.isAppend ? '请输入追加评价内容' : '请输入评价内容',
                  hintStyle: const TextStyle(
                    color: Color(0xFF92c9a4),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 匿名评论选项
            if (!widget.isAppend) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '匿名评论',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                      });
                    },
                    activeColor: const Color(0xFF13ec5b),
                    activeTrackColor: const Color(0xFF1a3525),
                    inactiveThumbColor: const Color(0xFF326744),
                    inactiveTrackColor: const Color(0xFF1a3525),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // 上传图片
            if (!widget.isAppend) ...[
              const Text(
                '上传图片',
                style: TextStyle(
                  color: Colors.white,
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
                        color: const Color(0xFF1a3525),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF326744).withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFF92c9a4),
                        size: 32,
                      ),
                    ),
                  ),
                  // 已选择的图片
                  ..._selectedImages.map((image) => Container(
                        margin: const EdgeInsets.all(8), // 添加外边距，避免删除按钮被遮挡
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFF2a4532),
                              ),
                              child: Image.file(
                                image,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // 删除按钮
                            Positioned(
                              top: -4, // 调整位置，避免被遮挡
                              right: -4, // 调整位置，避免被遮挡
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
                                    color: const Color(0xFFff4757),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
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
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '最多可上传5张图片',
                style: TextStyle(
                  color: Color(0xFF92c9a4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 32),
            ],

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
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
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Color(0xFF112217))
                    : Text(widget.isAppend ? '提交追加评价' : '提交评价'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}