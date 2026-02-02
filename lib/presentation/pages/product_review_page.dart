import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/core/services/image_loader_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/theme/theme_provider.dart';

/// 商品审核状态枚举
enum ProductReviewStatus {
  pending, // 待审核
  approved, // 已通过
  rejected, // 已驳回
}

/// 管理员权限枚举
enum AdminPermission {
  normal, // 普通审核员
  advanced, // 高级审核员
  superAdmin, // 超级管理员
}

/// 权限描述映射
const Map<AdminPermission, String> permissionDescriptions = {
  AdminPermission.normal: '普通审核员',
  AdminPermission.advanced: '高级审核员',
  AdminPermission.superAdmin: '超级管理员',
};

/// 权限功能映射
const Map<AdminPermission, List<String>> permissionFeatures = {
  AdminPermission.normal: [
    '仅可审核待审核商品',
    '不可修改已通过商品',
    '可查看审核日志',
    '可导出审核记录',
  ],
  AdminPermission.advanced: [
    '可审核所有状态商品',
    '可修改已通过商品',
    '可查看审核日志',
    '可导出审核记录',
    '可配置基础合规规则',
  ],
  AdminPermission.superAdmin: [
    '可修改所有审核结果',
    '可导出全量日志',
    '可配置合规预警规则',
    '可管理管理员权限',
    '可查看操作日志',
  ],
};

/// 合规校验结果模型
class ComplianceCheckResult {
  final bool isCompliant;
  final List<String> warnings;
  final List<String> errors;

  ComplianceCheckResult({
    required this.isCompliant,
    required this.warnings,
    required this.errors,
  });
}

/// 审核日志数据模型
class AuditLog {
  final String operator;
  final DateTime time;
  final String result;
  final String reason;
  final String remark;

  AuditLog({
    required this.operator,
    required this.time,
    required this.result,
    required this.reason,
    required this.remark,
  });
}

/// 商品审核页面 - 主列表页面
class ProductReviewPage extends ConsumerStatefulWidget {
  const ProductReviewPage({super.key});

  @override
  ConsumerState<ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends ConsumerState<ProductReviewPage> {
  /// 当前管理员权限（模拟，实际项目中应从登录状态获取）
  final AdminPermission _currentPermission = AdminPermission.advanced;

  /// 当前选中的标签索引
  int _selectedTabIndex = 0;

  /// 筛选条件状态
  bool _pendingChecked = true;
  bool _approvedChecked = false;
  bool _rejectedChecked = false;
  bool _resubmittedChecked = false;
  String _merchantName = '';
  String _startTime = '';
  String _endTime = '';
  bool _showWarningProducts = false;

  /// 批量选择状态
  bool _isAllSelected = false;
  final Set<int> _selectedProductIds = {};

  /// 当前选中的商品
  StarProduct? _selectedProduct;

  /// 审核日志映射，key: 商品ID，value: 审核日志列表
  final Map<int, List<AuditLog>> _auditLogs = {};

  /// 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  /// 待审核商品列表
  List<StarProduct> _pendingProducts = [];

  /// 已通过商品列表
  List<StarProduct> _approvedProducts = [];

  /// 已驳回商品列表
  List<StarProduct> _rejectedProducts = [];

  @override
  void initState() {
    super.initState();
    // 加载商品数据
    _loadData();
  }

  /// 从数据库加载商品数据
  Future<void> _loadData() async {
    try {
      // 获取所有商品
      final allProducts = await _databaseService.getAllStarProducts();
      
      setState(() {
        // 按状态分类商品
        _pendingProducts = allProducts.where((product) => product.status == 'pending').toList();
        _approvedProducts = allProducts.where((product) => product.status == 'approved').toList();
        _rejectedProducts = allProducts.where((product) => product.status == 'rejected').toList();
      });
    } catch (e) {
      print('加载商品数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '商品审核',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: () {
              // 刷新功能
              _refreshProducts();
            },
          ),
          IconButton(
            icon: Icon(Icons.download, color: theme.colorScheme.onSurface),
            onPressed: () {
              // 导出审核记录
              _exportReviewRecords();
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            onPressed: () {
              // 更多操作
              _showMoreOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部筛选栏
          _buildFilterTopBar(),
          // 主内容区
          Expanded(
            child: Row(
              children: [
                // 中间商品列表
                Expanded(
                  flex: 2,
                  child: _buildMainContent(),
                ),
                // 右侧详情/操作区
                Expanded(
                  flex: 3,
                  child: _buildProductDetail(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建顶部筛选栏
  Widget _buildFilterTopBar() {
    final theme = ref.watch(currentThemeProvider);
    final ScrollController horizontalScrollController = ScrollController();
    double _startX = 0.0;
    double _startOffset = 0.0;
    bool _showAdvancedFilters = false;

    return Container(
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onPanStart: (details) {
              _startX = details.globalPosition.dx;
              _startOffset = horizontalScrollController.offset;
            },
            onPanUpdate: (details) {
              if (horizontalScrollController.hasClients) {
                final deltaX = details.globalPosition.dx - _startX;
                final newPosition = (_startOffset - deltaX)
                    .clamp(
                      horizontalScrollController.position.minScrollExtent,
                      horizontalScrollController.position.maxScrollExtent,
                    );
                horizontalScrollController.jumpTo(newPosition);
              }
            },
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  // 基础筛选 - 按使用频率排序：审核状态 > 商户名称 > 时间范围
                  // 1. 审核状态（最常用）
                  Row(
                    children: [
                      _buildStatusChip('待审核', isSelected: _pendingChecked, theme: theme),
                      const SizedBox(width: 8),
                      _buildStatusChip('通过', isSelected: _approvedChecked, theme: theme),
                      const SizedBox(width: 8),
                      _buildStatusChip('驳回', isSelected: _rejectedChecked, theme: theme),
                      const SizedBox(width: 8),
                      _buildStatusChip('重提', isSelected: _resubmittedChecked, theme: theme),
                    ],
                  ),
                  const SizedBox(width: 24),
                  
                  // 2. 商户名称（次常用）
                  Row(
                    children: [
                      Text(
                        '商户: ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            hintText: '输入商户名称',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant, size: 16),
                          ),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                          onChanged: (value) {
                            setState(() {
                              _merchantName = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  
                  // 3. 时间范围（常用）
                  Row(
                    children: [
                      Text(
                        '时间: ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            hintText: '近7天',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            suffixIcon: Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant, size: 16),
                          ),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                          onChanged: (value) {
                            setState(() {
                              _startTime = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTimeChip('近7天', theme: theme),
                      const SizedBox(width: 6),
                      _buildTimeChip('近30天', theme: theme),
                    ],
                  ),
                  const SizedBox(width: 24),
                  
                  // 高级筛选折叠按钮
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAdvancedFilters = !_showAdvancedFilters;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _showAdvancedFilters ? '收起筛选' : '更多筛选',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _showAdvancedFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: theme.colorScheme.onSurface,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // 应用筛选和重置按钮（固定位置）
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('筛选'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('重置'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // 高级筛选区域（可折叠）
          if (_showAdvancedFilters)
            const SizedBox(height: 16),
          if (_showAdvancedFilters)
            GestureDetector(
              onPanStart: (details) {
                _startX = details.globalPosition.dx;
                _startOffset = horizontalScrollController.offset;
              },
              onPanUpdate: (details) {
                if (horizontalScrollController.hasClients) {
                  final deltaX = details.globalPosition.dx - _startX;
                  final newPosition = (_startOffset - deltaX)
                      .clamp(
                        horizontalScrollController.position.minScrollExtent,
                        horizontalScrollController.position.maxScrollExtent,
                      );
                  horizontalScrollController.jumpTo(newPosition);
                }
              },
              child: SingleChildScrollView(
                controller: horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    // 高级筛选内容
                    Row(
                      children: [
                        Checkbox(
                          value: _showWarningProducts,
                          onChanged: (value) {
                            setState(() {
                              _showWarningProducts = value ?? false;
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                          checkColor: theme.colorScheme.onPrimary,
                          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
                        ),
                        Text(
                          '仅看预警',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    
                    // 可以添加更多高级筛选条件
                    Row(
                      children: [
                        Text(
                          '商品分类: ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              hintText: '全部分类',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                              suffixIcon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant, size: 16),
                            ),
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    
                    Row(
                      children: [
                        Text(
                          '价格范围: ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              hintText: '最低',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            ),
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              hintText: '最高',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            ),
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


  
  /// 构建复选框项
  Widget _buildCheckboxItem(String label, {required ThemeData theme}) {
    bool isChecked = false;
    switch (label) {
      case '待审核':
        isChecked = _pendingChecked;
        break;
      case '审核通过':
        isChecked = _approvedChecked;
        break;
      case '审核驳回':
        isChecked = _rejectedChecked;
        break;
      case '重新提交':
        isChecked = _resubmittedChecked;
        break;
      case '仅显示系统预警商品':
        isChecked = _showWarningProducts;
        break;
    }

    return Row(
      children: [
        Checkbox(
          value: isChecked,
          onChanged: (value) {
            setState(() {
              switch (label) {
                case '待审核':
                  _pendingChecked = value ?? false;
                  break;
                case '审核通过':
                  _approvedChecked = value ?? false;
                  break;
                case '审核驳回':
                  _rejectedChecked = value ?? false;
                  break;
                case '重新提交':
                  _resubmittedChecked = value ?? false;
                  break;
                case '仅显示系统预警商品':
                  _showWarningProducts = value ?? false;
                  break;
              }
            });
          },
          activeColor: theme.colorScheme.primary,
          checkColor: theme.colorScheme.onPrimary,
          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  /// 构建时间选择标签
  Widget _buildTimeChip(String label, {required ThemeData theme}) {
    return GestureDetector(
      onTap: () {
        // 点击时间标签的处理逻辑
        print('点击时间标签: $label');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// 构建审核状态标签
  Widget _buildStatusChip(String label, {bool isSelected = false, required ThemeData theme}) {
    Color bgColor = isSelected ? theme.colorScheme.primary : theme.colorScheme.surface;
    Color textColor = isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    Color borderColor = isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5);
    
    return GestureDetector(
      onTap: () {
        // 点击状态标签的处理逻辑
        setState(() {
          switch (label) {
            case '待审核':
              _pendingChecked = !_pendingChecked;
              break;
            case '通过':
              _approvedChecked = !_approvedChecked;
              break;
            case '驳回':
              _rejectedChecked = !_rejectedChecked;
              break;
            case '重提':
              _resubmittedChecked = !_resubmittedChecked;
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  /// 构建主内容区
  Widget _buildMainContent() {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // 顶部操作栏
          _buildTopActionBar(theme),
          // 商品列表
            Expanded(
              child: _buildProductList(),
            ),
        ],
      ),
    );
  }
  
  /// 构建顶部操作栏
  Widget _buildTopActionBar(ThemeData theme) {
    // 只有选中商品时，批量操作按钮才可用
    bool hasSelectedProducts = _selectedProductIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 批量操作按钮
          Row(
            children: [
              ElevatedButton(
                onPressed: hasSelectedProducts ? () {
                  // 批量通过
                  _batchApproveProducts();
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('批量通过'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: hasSelectedProducts ? () {
                  // 批量驳回
                  _batchRejectProducts();
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('批量驳回'),
              ),
            ],
          ),
          // 商品数量统计
          Flexible(
            child: Text(
              '共 ${_getAllProducts().length} 条商品，其中 ${_getAllProducts().where((p) => p.status == 'pending').length} 条待审核',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 审核通过单个商品
  void _approveProduct(StarProduct product) {
    // 弹出二次确认对话框
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '审核通过确认',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                '确认审核通过商品「${product.name}」吗？',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '审核通过后，商品将自动同步到平台商品库，买家可直接购买。',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '取消',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
            // 确认按钮
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 执行审核通过操作
                _executeApproveProduct(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('确认通过'),
            ),
          ],
        );
      },
    );
  }

  /// 执行审核通过操作
  void _executeApproveProduct(StarProduct product) async {
    // 生成审核日志
    final auditLog = AuditLog(
      operator: 'admin',
      time: DateTime.now(),
      result: '审核通过',
      reason: '',
      remark: '',
    );
    
    try {
      // 创建新的商品对象，更新状态
      final updatedProduct = StarProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        image: product.image,
        mainImages: product.mainImages,
        productCode: product.productCode,
        points: product.points,
        costPrice: product.costPrice,
        stock: product.stock,
        categoryId: product.categoryId,
        brand: product.brand,
        tags: product.tags,
        categoryPath: product.categoryPath,
        isActive: product.isActive,
        isDeleted: product.isDeleted,
        status: 'approved',
        shippingTemplateId: product.shippingTemplateId,
        isPreSale: product.isPreSale,
        preSaleEndTime: product.preSaleEndTime,
        releaseTime: product.releaseTime,
        scheduledReleaseTime: product.scheduledReleaseTime,
        sales7Days: product.sales7Days,
        totalSales: product.totalSales,
        visitors: product.visitors,
        conversionRate: product.conversionRate,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: product.deletedAt,
        skus: product.skus,
        specs: product.specs,
        video: product.video,
        videoCover: product.videoCover,
        videoDescription: product.videoDescription,
        detailImages: product.detailImages,
        detail: product.detail,
        weight: product.weight,
        volume: product.volume,
        originalPrice: product.originalPrice,
        price: product.price,
        memberPrice: product.memberPrice,
        shippingTime: product.shippingTime,
        shippingAddress: product.shippingAddress,
        returnPolicy: product.returnPolicy,
        sortWeight: product.sortWeight,
        isLimitedPurchase: product.isLimitedPurchase,
        limitQuantity: product.limitQuantity,
        internalNote: product.internalNote,
        seoTitle: product.seoTitle,
        seoKeywords: product.seoKeywords,
      );
      
      // 保存到数据库
      await _databaseService.updateStarProduct(updatedProduct);
      
      // 更新本地状态
      setState(() {
        // 从待审核列表中移除
        _pendingProducts.removeWhere((p) => p.id == product.id);
        // 添加到已通过列表
        _approvedProducts.add(updatedProduct);
        // 如果当前选中的是该商品，更新选中状态
        if (_selectedProduct?.id == product.id) {
          _selectedProduct = updatedProduct;
        }
        // 从选中列表中移除
        _selectedProductIds.remove(product.id);
        // 更新全选状态
        _updateAllSelectedState();
        // 存储审核日志
        if (product.id != null) {
          _saveAuditLog(product.id!, auditLog);
        }
      });
      
      // 显示审核通过成功提示
      final theme = ref.watch(currentThemeProvider);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('商品「${product.name}」审核通过，已同步至平台商品库'),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('审核通过商品失败: $e');
      // 显示审核失败提示
      final theme = ref.watch(currentThemeProvider);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('商品「${product.name}」审核通过失败，请重试'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 存储审核日志
  void _saveAuditLog(int productId, AuditLog log) {
    if (!_auditLogs.containsKey(productId)) {
      _auditLogs[productId] = [];
    }
    _auditLogs[productId]!.add(log);
  }

  /// 批量审核通过商品
  void _batchApproveProducts() {
    // 弹出批量通过确认对话框
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '批量通过确认',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                '确认批量通过选中的 ${_selectedProductIds.length} 条商品？',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '此操作将把选中的商品状态更改为「审核通过」，并同步到平台商品库。',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '取消',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
            // 确认按钮
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 执行批量通过操作
                _executeBatchApprove();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确认通过'),
            ),
          ],
        );
      },
    );
  }

  /// 执行批量通过操作
  void _executeBatchApprove() {
    // 这里可以添加批量审核通过的逻辑
    print('批量审核通过 ${_selectedProductIds.length} 个商品');
    setState(() {
      // 遍历选中的商品ID
      for (var id in _selectedProductIds) {
        // 找到对应的商品
        StarProduct product = _pendingProducts.firstWhere((p) => p.id == id);
        // 从待审核列表中移除
        _pendingProducts.remove(product);
        // 创建新的商品对象，更新状态
        final updatedProduct = StarProduct(
          id: product.id,
          name: product.name,
          description: product.description,
          image: product.image,
          mainImages: product.mainImages,
          productCode: product.productCode,
          points: product.points,
          costPrice: product.costPrice,
          stock: product.stock,
          categoryId: product.categoryId,
          brand: product.brand,
          tags: product.tags,
          categoryPath: product.categoryPath,
          isActive: product.isActive,
          isDeleted: product.isDeleted,
          status: 'approved',
          shippingTemplateId: product.shippingTemplateId,
          isPreSale: product.isPreSale,
          preSaleEndTime: product.preSaleEndTime,
          releaseTime: product.releaseTime,
          scheduledReleaseTime: product.scheduledReleaseTime,
          sales7Days: product.sales7Days,
          totalSales: product.totalSales,
          visitors: product.visitors,
          conversionRate: product.conversionRate,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
          deletedAt: product.deletedAt,
          skus: product.skus,
          specs: product.specs,
          video: product.video,
          videoCover: product.videoCover,
          videoDescription: product.videoDescription,
          detailImages: product.detailImages,
          detail: product.detail,
          weight: product.weight,
          volume: product.volume,
          originalPrice: product.originalPrice,
          price: product.price,
          memberPrice: product.memberPrice,
          shippingTime: product.shippingTime,
          shippingAddress: product.shippingAddress,
          returnPolicy: product.returnPolicy,
          sortWeight: product.sortWeight,
          isLimitedPurchase: product.isLimitedPurchase,
          limitQuantity: product.limitQuantity,
          internalNote: product.internalNote,
          seoTitle: product.seoTitle,
          seoKeywords: product.seoKeywords,
        );
        // 添加到已通过列表
        _approvedProducts.add(updatedProduct);
        // 如果当前选中的是该商品，更新选中状态
        if (_selectedProduct?.id == product.id) {
          _selectedProduct = updatedProduct;
        }
        // 生成审核日志
        final auditLog = AuditLog(
          operator: 'admin',
          time: DateTime.now(),
          result: '审核通过',
          reason: '',
          remark: '批量审核通过',
        );
        // 存储审核日志
        if (product.id != null) {
          _saveAuditLog(product.id!, auditLog);
        }
      }
      // 清空选中列表
      _selectedProductIds.clear();
      // 更新全选状态
      _updateAllSelectedState();
      // 显示批量通过成功提示
      final theme = ref.watch(currentThemeProvider);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('已批量通过 ${_selectedProductIds.length} 条商品'),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// 批量驳回商品
  void _batchRejectProducts() {
    String rejectReason = '资质缺失';
    String customRemark = '';
    
    // 弹出批量驳回确认对话框
    showDialog(
      context: context,
      builder: (context) {
        final theme = ref.watch(currentThemeProvider);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '批量驳回确认',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    '请选择驳回原因',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 驳回原因模板选择
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var reason in ['资质缺失', '商品信息违规', '素材违规', '价格异常', '其他']) 
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              rejectReason = reason;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: rejectReason == reason ? theme.colorScheme.primary : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: rejectReason == reason ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '自定义备注（可选）',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '请输入额外的驳回原因或备注',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    maxLines: 3,
                    onChanged: (value) {
                      customRemark = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '确认批量驳回选中的 ${_selectedProductIds.length} 条商品？',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                '取消',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
            // 确认按钮
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 执行批量驳回操作
                _executeBatchReject(rejectReason, customRemark);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确认驳回'),
            ),
          ],
        );
      },
    );
  }

  /// 执行批量驳回操作
  void _executeBatchReject(String reason, String remark) {
    print('批量驳回 ${_selectedProductIds.length} 个商品，原因：$reason，备注：$remark');
    // 模拟批量驳回
    setState(() {
      // 遍历选中的商品ID
      for (var id in _selectedProductIds) {
        // 找到对应的商品
        StarProduct product = _pendingProducts.firstWhere((p) => p.id == id);
        // 从待审核列表中移除
        _pendingProducts.remove(product);
        // 创建新的商品对象，更新状态
        final updatedProduct = StarProduct(
          id: product.id,
          name: product.name,
          description: product.description,
          image: product.image,
          mainImages: product.mainImages,
          productCode: product.productCode,
          points: product.points,
          costPrice: product.costPrice,
          stock: product.stock,
          categoryId: product.categoryId,
          brand: product.brand,
          tags: product.tags,
          categoryPath: product.categoryPath,
          isActive: product.isActive,
          isDeleted: product.isDeleted,
          status: 'rejected',
          shippingTemplateId: product.shippingTemplateId,
          isPreSale: product.isPreSale,
          preSaleEndTime: product.preSaleEndTime,
          releaseTime: product.releaseTime,
          scheduledReleaseTime: product.scheduledReleaseTime,
          sales7Days: product.sales7Days,
          totalSales: product.totalSales,
          visitors: product.visitors,
          conversionRate: product.conversionRate,
          createdAt: product.createdAt,
          updatedAt: DateTime.now(),
          deletedAt: product.deletedAt,
          skus: product.skus,
          specs: product.specs,
          video: product.video,
          videoCover: product.videoCover,
          videoDescription: product.videoDescription,
          detailImages: product.detailImages,
          detail: product.detail,
          weight: product.weight,
          volume: product.volume,
          originalPrice: product.originalPrice,
          price: product.price,
          memberPrice: product.memberPrice,
          shippingTime: product.shippingTime,
          shippingAddress: product.shippingAddress,
          returnPolicy: product.returnPolicy,
          sortWeight: product.sortWeight,
          isLimitedPurchase: product.isLimitedPurchase,
          limitQuantity: product.limitQuantity,
          internalNote: product.internalNote,
          seoTitle: product.seoTitle,
          seoKeywords: product.seoKeywords,
        );
        // 添加到已驳回列表
        _rejectedProducts.add(updatedProduct);
        // 如果当前选中的是该商品，更新选中状态
        if (_selectedProduct?.id == product.id) {
          _selectedProduct = updatedProduct;
        }
        // 生成审核日志
        final auditLog = AuditLog(
          operator: 'admin',
          time: DateTime.now(),
          result: '审核驳回',
          reason: reason,
          remark: remark,
        );
        // 存储审核日志
        if (product.id != null) {
          _saveAuditLog(product.id!, auditLog);
        }
      }
      // 清空选中列表
      _selectedProductIds.clear();
      // 更新全选状态
      _updateAllSelectedState();
      // 显示批量驳回成功提示
      final theme = ref.watch(currentThemeProvider);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('已批量驳回 ${_selectedProductIds.length} 条商品'),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// 应用筛选条件
  void _applyFilters() {
    // 这里可以添加筛选逻辑
    // 目前我们只是打印筛选条件，实际项目中应该调用API或过滤本地数据
    print('应用筛选条件:');
    print('待审核: $_pendingChecked');
    print('审核通过: $_approvedChecked');
    print('审核驳回: $_rejectedChecked');
    print('重新提交: $_resubmittedChecked');
    print('商户名称: $_merchantName');
    print('开始时间: $_startTime');
    print('结束时间: $_endTime');
    print('仅显示系统预警商品: $_showWarningProducts');
  }

  /// 重置筛选条件
  void _resetFilters() {
    setState(() {
      _pendingChecked = true;
      _approvedChecked = false;
      _rejectedChecked = false;
      _resubmittedChecked = false;
      _merchantName = '';
      _startTime = '';
      _endTime = '';
      _showWarningProducts = false;
    });
  }

  /// 获取所有商品列表（合并所有状态）
  List<StarProduct> _getAllProducts() {
    return [..._pendingProducts, ..._approvedProducts, ..._rejectedProducts];
  }

  /// 内置禁售词列表
  final List<String> _prohibitedWords = [
    '高仿', '违禁', '假货', '盗版', '走私', '毒品', '武器', '爆炸物',
    '反动', '色情', '暴力', '赌博', '诈骗', '侵权', '假冒', '伪劣',
  ];

  /// 检查商品名称和描述是否包含禁售词
  List<String> _checkProhibitedWords(StarProduct product) {
    List<String> violations = [];
    
    // 检查商品名称
    for (var word in _prohibitedWords) {
      if (product.name.toLowerCase().contains(word.toLowerCase())) {
        violations.add('商品名称包含禁售词: $word');
      }
    }
    
    // 检查商品描述
    if (product.description != null) {
      for (var word in _prohibitedWords) {
        if (product.description!.toLowerCase().contains(word.toLowerCase())) {
          violations.add('商品描述包含禁售词: $word');
        }
      }
    }
    
    return violations;
  }

  /// 检查价格是否异常
  List<String> _checkPriceAbnormality(StarProduct product) {
    List<String> violations = [];
    
    // 价格异常检查逻辑：价格过低或过高
    if (product.price <= 0) {
      violations.add('价格异常: 价格不能为0或负数');
    } else if (product.price > 1000000) {
      violations.add('价格异常: 价格过高，请检查是否输入错误');
    }
    
    // 检查原价与现价的差异
    if (product.originalPrice != null && product.originalPrice! > 0) {
      double discount = product.price / product.originalPrice!;
      if (discount < 0.1) {
        violations.add('价格异常: 折扣过低（低于1折），请检查是否输入错误');
      }
    }
    
    return violations;
  }

  /// 检查商品分类与经营范围是否匹配
  List<String> _checkCategoryMatch(StarProduct product) {
    List<String> violations = [];
    
    // 模拟商户经营范围
    // 实际项目中，应该从商户信息中获取经营范围
    final List<String> merchantBusinessScope = ['电子产品', '数码配件', '服装', '鞋帽'];
    
    // 获取商品分类路径
    final List<String> categoryPath = (product.categoryPath ?? '').split('>');
    // 获取商品最细分类
    final String productCategory = categoryPath.isNotEmpty ? categoryPath.last : '';
    
    // 检查商品分类是否在商户经营范围中
    bool isCategoryMatch = false;
    for (var scope in merchantBusinessScope) {
      if (productCategory.contains(scope) || scope.contains(productCategory)) {
        isCategoryMatch = true;
        break;
      }
    }
    
    if (!isCategoryMatch) {
      violations.add('分类不匹配: 商品分类 "$productCategory" 不在商户经营范围 "${merchantBusinessScope.join(', ')}" 内');
    }
    
    return violations;
  }

  /// 检查商户资质是否缺失或不匹配
  List<String> _checkMerchantQualifications(StarProduct product) {
    List<String> violations = [];
    
    // 模拟资质检查逻辑
    // 实际项目中，应该从商户信息中获取资质信息进行检查
    String category = (product.categoryPath ?? '').split('>').last;
    
    // 假设某些商品分类需要特殊资质
    final Map<String, List<String>> requiredQualifications = {
      '食品': ['食品经营许可证'],
      '化妆品': ['化妆品生产许可证', '化妆品卫生许可证'],
      '医疗器械': ['医疗器械经营许可证'],
    };
    
    if (requiredQualifications.containsKey(category)) {
      // 模拟资质缺失情况
      if (category == '食品') {
        // 模拟食品分类商品没有食品经营许可证
        violations.add('资质缺失: 缺少食品经营许可证');
      }
    }
    
    return violations;
  }

  /// 执行合规校验
  ComplianceCheckResult _performComplianceCheck(StarProduct product) {
    List<String> warnings = [];
    List<String> errors = [];
    
    // 检查禁售词
    List<String> prohibitedWordViolations = _checkProhibitedWords(product);
    errors.addAll(prohibitedWordViolations);
    
    // 检查价格异常
    List<String> priceViolations = _checkPriceAbnormality(product);
    warnings.addAll(priceViolations);
    
    // 检查商户资质
    List<String> qualificationViolations = _checkMerchantQualifications(product);
    errors.addAll(qualificationViolations);
    
    // 检查分类与经营范围匹配
    List<String> categoryMatchViolations = _checkCategoryMatch(product);
    errors.addAll(categoryMatchViolations);
    
    return ComplianceCheckResult(
      isCompliant: errors.isEmpty && warnings.isEmpty,
      warnings: warnings,
      errors: errors,
    );
  }

  /// 构建合规预警标记
  Widget _buildComplianceWarning(StarProduct product, {required ThemeData theme}) {
    ComplianceCheckResult result = _performComplianceCheck(product);
    
    if (result.isCompliant) {
      return const SizedBox(); // 合规商品不显示预警
    }
    
    return Row(
      children: [
        const SizedBox(width: 8),
        Tooltip(
          message: _buildComplianceTooltip(result),
          child: Icon(
            result.errors.isNotEmpty ? Icons.error : Icons.warning,
            color: result.errors.isNotEmpty ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            size: 16,
          ),
        ),
      ],
    );
  }

  /// 构建合规预警提示文本
  String _buildComplianceTooltip(ComplianceCheckResult result) {
    String tooltip = '';
    
    if (result.errors.isNotEmpty) {
      tooltip += '存在违规问题：\n';
      for (var error in result.errors) {
        tooltip += '- $error\n';
      }
    }
    
    if (result.warnings.isNotEmpty) {
      tooltip += '存在警告信息：\n';
      for (var warning in result.warnings) {
        tooltip += '- $warning\n';
      }
    }
    
    return tooltip.trim();
  }

  /// 构建详细的合规校验结果
  Widget _buildComplianceCheckResults(StarProduct product, {required ThemeData theme}) {
    final checkResult = _performComplianceCheck(product);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 合规总体状态
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '总体合规状态',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: checkResult.isCompliant ? theme.colorScheme.primary : theme.colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                checkResult.isCompliant ? '合规' : '不合规',
                style: TextStyle(
                  color: checkResult.isCompliant ? theme.colorScheme.onPrimary : theme.colorScheme.onError,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 详细合规检查结果
        if (checkResult.errors.isNotEmpty || checkResult.warnings.isNotEmpty) ...[
          Text(
            '详细检查结果',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 违规问题
          if (checkResult.errors.isNotEmpty) ...[
            Text(
              '违规问题',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: checkResult.errors.map((error) => _buildComplianceItem(error, isError: true, theme: theme)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // 警告信息
          if (checkResult.warnings.isNotEmpty) ...[
            Text(
              '警告信息',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: checkResult.warnings.map((warning) => _buildComplianceItem(warning, theme: theme)).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ] else ...[
          // 没有违规或警告
          Text(
            '该商品符合所有合规规则，未发现违规问题或警告信息。',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
        
        // 合规规则说明
        Text(
          '合规规则说明',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '• 禁售词检查：检测商品名称和描述中是否包含违禁词汇\n' +
          '• 价格异常检查：检测商品价格是否过低或过高\n' +
          '• 商户资质校验：检测商户是否具备销售该商品的资质\n' +
          '• 分类匹配校验：检测商品分类与经营范围是否匹配',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// 构建合规项
  Widget _buildComplianceItem(String content, {bool isError = false, required ThemeData theme}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.warning,
            color: isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品列表
  Widget _buildProductList() {
    final theme = ref.watch(currentThemeProvider);
    // 获取所有商品
    List<StarProduct> allProducts = _getAllProducts();
    
    // 应用筛选条件
    List<StarProduct> filteredProducts = allProducts.where((product) {
      // 审核状态筛选
      bool statusMatch = false;
      if ((product.status == 'pending' && _pendingChecked) ||
          (product.status == 'approved' && _approvedChecked) ||
          (product.status == 'rejected' && _rejectedChecked) ||
          (product.status == 'resubmitted' && _resubmittedChecked)) {
        statusMatch = true;
      }
      
      // 商户名称筛选（模糊匹配）
      bool merchantMatch = _merchantName.isEmpty || 
                          (product.brand?.toLowerCase().contains(_merchantName.toLowerCase()) ?? false);
      
      
      // 系统预警商品筛选
      bool warningMatch = !_showWarningProducts; // 目前我们没有预警商品的字段，所以默认显示所有
      
      return statusMatch && merchantMatch && warningMatch;
    }).toList();

    return Column(
      children: [
        // 全选复选框和统计信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: _isAllSelected,
                onChanged: (value) {
                  setState(() {
                    _isAllSelected = value ?? false;
                    if (_isAllSelected) {
                      // 全选：只选择待审核的商品
                      _selectedProductIds.clear();
                      for (var product in filteredProducts) {
                        if (product.status == 'pending' && product.id != null) {
                          _selectedProductIds.add(product.id!);
                        }
                      }
                    } else {
                      // 取消全选
                      _selectedProductIds.clear();
                    }
                  });
                },
                activeColor: theme.colorScheme.primary,
                checkColor: theme.colorScheme.onPrimary,
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              const SizedBox(width: 8),
              Text(
                '全选',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                '共 ${filteredProducts.length} 条商品，其中 ${filteredProducts.where((p) => p.status == 'pending').length} 条待审核',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // 商品列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _buildProductItem(product, theme);
            },
          ),
        ),
      ],
    );
  }

  /// 构建商品项
  Widget _buildProductItem(StarProduct product, ThemeData theme) {
    // 只有待审核的商品可以勾选
    bool canSelect = product.status == 'pending';
    bool isSelected = _selectedProductIds.contains(product.id);
    bool isCurrentSelected = _selectedProduct?.id == product.id;

    return GestureDetector(
      onTap: () {
        // 设置当前选中的商品
        setState(() {
          _selectedProduct = product;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentSelected ? theme.colorScheme.surfaceVariant : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrentSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5)),
          boxShadow: isCurrentSelected ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          children: [
            // 复选框
            Checkbox(
              value: isSelected,
              onChanged: canSelect ? (value) {
                setState(() {
                  if (value ?? false) {
                    _selectedProductIds.add(product.id!);
                  } else {
                    _selectedProductIds.remove(product.id!);
                  }
                  // 更新全选状态
                  _updateAllSelectedState();
                });
              } : null,
              activeColor: theme.colorScheme.primary,
              checkColor: theme.colorScheme.onPrimary,
              side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
              tristate: false,
            ),
            const SizedBox(width: 12),
            // 商品图片
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: ImageLoaderService.getImageProvider(product.image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 商品信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 合规预警标记
                                _buildComplianceWarning(product, theme: theme),
                          ],
                        ),
                      ),
                      // 审核状态标签 - 可点击筛选，不同状态不同颜色
                      GestureDetector(
                        onTap: () {
                          // 点击状态标签，设置对应筛选条件
                          setState(() {
                            _pendingChecked = product.status == 'pending';
                            _approvedChecked = product.status == 'approved';
                            _rejectedChecked = product.status == 'rejected';
                            _resubmittedChecked = product.status == 'resubmitted';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(product.status, theme),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            _getStatusText(product.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 商品基本信息 - 改为多行显示，避免水平溢出
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '商品ID: ${product.id}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '价格: ¥${product.price}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '分类: ${product.categoryPath}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 商户信息
                  Row(
                    children: [
                      Icon(
                        Icons.storefront,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${product.brand} 官方旗舰店',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 提交时间和操作按钮
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提交时间
                      Text(
                        '${product.createdAt.toString().substring(0, 19)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 操作按钮 - 改为水平滚动，避免溢出
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 待审核商品显示「审核」按钮，已审核商品显示「查看」按钮
                            if (product.status == 'pending') ...[
                              ElevatedButton(
                                onPressed: () {
                                  // 审核通过
                                  _approveProduct(product);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('通过'),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: () {
                                  // 驳回商品
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: theme.colorScheme.surfaceVariant,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(24),
                                        topRight: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (context) => _buildRejectModal(context, product),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('驳回'),
                              ),
                            ],
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () {
                                // 设置当前选中的商品
                                setState(() {
                                  _selectedProduct = product;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('查看'),
                            ),
                          ],
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
    );
  }

  /// 构建商品详情/操作区
  Widget _buildProductDetail() {
    final theme = ref.watch(currentThemeProvider);
    if (_selectedProduct == null) {
      // 未选中商品时显示提示
      return Container(
        color: theme.colorScheme.surface,
        child: Center(
          child: Text(
            '请选择一个商品查看详情',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final product = _selectedProduct!;

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品基本信息
            Text(
              '商品基本信息',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 商品图片 - 添加点击放大功能
                      GestureDetector(
                        onTap: () {
                          // 点击放大图片
                          print('放大图片: ${product.image}');
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: ImageLoaderService.getImageProvider(product.image),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 商品信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '商品ID: ${product.id}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '商品编码: ${product.productCode}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '分类: ${product.categoryPath}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '品牌: ${product.brand}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '价格: ¥${product.price}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '库存: ${product.stock}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '上架状态: ${product.isActive ? '已上架' : '未上架'}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '预售状态: ${product.isPreSale ? '是' : '否'}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 商品描述
                  Text(
                    '商品描述',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description ?? '',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 规格信息 - 添加查看全部功能
                  Text(
                    '规格信息',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // 查看全部规格
                      print('查看全部规格');
                    },
                    child: Text(
                      _formatSpecs(product.specs),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                        decoration: product.specs != null && product.specs!.isNotEmpty ? TextDecoration.underline : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 商品素材区
            Text(
              '商品素材区',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '商品主图',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 主图列表
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: product.mainImages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // 点击放大图片
                            print('放大主图: ${product.mainImages[index]}');
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: ImageLoaderService.getImageProvider(product.mainImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: const Align(
                              alignment: Alignment.bottomRight,
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (product.detailImages.isNotEmpty) ...[
                    Text(
                      '商品详情图',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 详情图列表
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: product.detailImages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // 点击放大详情图
                            print('放大详情图: ${product.detailImages[index]}');
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: ImageLoaderService.getImageProvider(product.detailImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  // 商品视频
                  if (product.video != null && product.video!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      '商品视频',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        // 播放视频
                        print('播放视频: ${product.video}');
                      },
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: product.videoCover != null 
                                ? ImageLoaderService.getImageProvider(product.videoCover!)
                                : const NetworkImage('https://via.placeholder.com/600x300?text=Video+Placeholder'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    if (product.videoDescription != null && product.videoDescription!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.videoDescription!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 合规校验结果
            Text(
              '合规校验结果',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              child: _buildComplianceCheckResults(product, theme: theme),
            ),
            const SizedBox(height: 24),
            
            // 商户资质校验
            Text(
              '商户资质校验',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '商户名称',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${product.brand} 官方旗舰店',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '资质状态',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '资质齐全',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '经营范围',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '电子产品、数码配件',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '合规校验结果',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '校验通过',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 审核操作区（根据权限和商品状态显示）
            // 普通审核员只能审核待审核商品，高级和超级管理员可以修改已审核商品
            if ((_currentPermission == AdminPermission.normal && product.status == 'pending') || 
                (_currentPermission != AdminPermission.normal)) ...[
              Text(
                '审核操作',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '审核结果',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 审核结果单选按钮
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // 选择通过
                              _approveProduct(product);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('通过'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // 选择驳回
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(24),
                                    topRight: Radius.circular(24),
                                  ),
                                ),
                                builder: (context) => _buildRejectModal(context, product),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('驳回'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // 审核日志区
            const SizedBox(height: 24),
            Text(
              '审核日志',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 显示实际审核日志
                  if (_auditLogs.containsKey(product.id) && _auditLogs[product.id]!.isNotEmpty)
                    ..._auditLogs[product.id]!.map((log) => Column(
                      children: [
                        _buildAuditLogItem(
                          operator: log.operator,
                          time: log.time,
                          result: log.result,
                          reason: log.reason,
                          remark: log.remark,
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ))
                  else
                    // 没有审核日志时显示提示
                    Text(
                      '暂无审核日志',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建审核日志项
  Widget _buildAuditLogItem({
    required String operator,
    required DateTime time,
    required String result,
    required String reason,
    required String remark,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                operator,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                time.toString().substring(0, 19),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '操作结果: ',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              Text(
                result,
                style: TextStyle(
                  color: result == '审核通过' ? theme.colorScheme.primary : result == '审核驳回' ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '驳回原因: ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (remark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '备注: ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: Text(
                    remark,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 刷新商品列表
  void _refreshProducts() {
    // 这里可以添加刷新商品列表的逻辑，例如调用API获取最新商品
    print('刷新商品列表');
    // 模拟刷新成功，显示提示
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('列表已更新，新增 0 条待审核商品'),
        backgroundColor: Color(0xFF13ec5b),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 导出审核记录
  void _exportReviewRecords() {
    // 这里可以添加导出审核记录的逻辑
    print('导出审核记录');
    // 弹出导出选项菜单
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2C20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String exportRange = '导出全部';
            String exportFormat = 'Excel';
            
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 拖拽指示器
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // 标题
                        const Text(
                          '导出审核记录',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 导出范围选项
                        const Text(
                          '导出范围',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            _buildExportOptionItem('导出全部', onChanged: (value) {
                              setState(() {
                                exportRange = value;
                              });
                            }, groupValue: exportRange),
                            _buildExportOptionItem('导出选中', onChanged: (value) {
                              setState(() {
                                exportRange = value;
                              });
                            }, groupValue: exportRange),
                            _buildExportOptionItem('导出近7天', onChanged: (value) {
                              setState(() {
                                exportRange = value;
                              });
                            }, groupValue: exportRange),
                            _buildExportOptionItem('导出近30天', onChanged: (value) {
                              setState(() {
                                exportRange = value;
                              });
                            }, groupValue: exportRange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 导出格式选项
                        const Text(
                          '导出格式',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildExportOptionItem('Excel', isButton: true, isSelected: exportFormat == 'Excel', onChanged: (value) {
                                setState(() {
                                  exportFormat = value;
                                });
                              }),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExportOptionItem('PDF', isButton: true, isSelected: exportFormat == 'PDF', onChanged: (value) {
                                setState(() {
                                  exportFormat = value;
                                });
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // 确认导出按钮
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              // 确认导出
                              Navigator.pop(context);
                              // 根据选择的范围和格式执行导出
                              _executeExport(exportRange, exportFormat);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13ec5b),
                              foregroundColor: const Color(0xFF102216),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('确认导出'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 导出选项说明
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF102216),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '导出说明',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '* 导出全部：导出所有审核记录（共 ${_getAllAuditRecordsCount()} 条）',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '* 导出选中：导出当前选中的 ${_selectedProductIds.length} 条商品的审核记录',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '* 导出近7天：导出最近7天的审核记录',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '* Excel格式支持数据筛选和编辑，PDF格式适合打印和分享',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 获取所有审核记录数量
  int _getAllAuditRecordsCount() {
    // 计算所有审核记录数量
    int count = 0;
    _auditLogs.forEach((key, logs) {
      count += logs.length;
    });
    return count;
  }

  /// 生成导出数据
  String _generateExportData(String exportRange) {
    // 构建CSV格式的导出数据
    StringBuffer csvData = StringBuffer();
    
    // 添加CSV表头
    csvData.writeln('商品ID,商品名称,审核状态,审核时间,操作人,审核结果,驳回原因,备注');
    
    // 根据导出范围筛选数据
    List<StarProduct> exportProducts = [];
    
    switch (exportRange) {
      case '导出全部':
        exportProducts = _getAllProducts();
        break;
      case '导出选中':
        exportProducts = _pendingProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
        break;
      case '导出近7天':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        exportProducts = _getAllProducts()
            .where((p) => p.createdAt.isAfter(sevenDaysAgo))
            .toList();
        break;
      case '导出近30天':
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        exportProducts = _getAllProducts()
            .where((p) => p.createdAt.isAfter(thirtyDaysAgo))
            .toList();
        break;
      default:
        exportProducts = _getAllProducts();
    }
    
    // 添加商品数据
    for (var product in exportProducts) {
      // 获取该商品的审核日志
      List<AuditLog> logs = _auditLogs[product.id] ?? [];
      AuditLog? latestLog = logs.isNotEmpty ? logs.last : null;
      
      // 构建CSV行
      csvData.writeln('${product.id},${product.name},${_getStatusText(product.status)},${product.createdAt},${latestLog?.operator ?? ''},${latestLog?.result ?? ''},${latestLog?.reason ?? ''},${latestLog?.remark ?? ''}');
    }
    
    return csvData.toString();
  }

  /// 执行导出操作
  Future<void> _executeExport(String exportRange, String exportFormat) async {
    // 根据选择的范围和格式执行导出
    List<StarProduct> exportProducts = [];
    
    // 根据导出范围筛选数据
    switch (exportRange) {
      case '导出全部':
        exportProducts = _getAllProducts();
        break;
      case '导出选中':
        exportProducts = _pendingProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
        break;
      case '导出近7天':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        exportProducts = _getAllProducts()
            .where((p) => p.createdAt.isAfter(sevenDaysAgo))
            .toList();
        break;
      case '导出近30天':
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        exportProducts = _getAllProducts()
            .where((p) => p.createdAt.isAfter(thirtyDaysAgo))
            .toList();
        break;
      default:
        exportProducts = _getAllProducts();
    }
    
    final recordCount = exportProducts.length;
    
    // 生成导出数据
    final exportData = _generateExportData(exportRange);
    
    // 执行实际的导出操作
    await _executeActualExport(exportData, exportFormat, exportRange);
    
    print('执行导出操作：范围=$exportRange，格式=$exportFormat，记录数=$recordCount');
  }

  /// 执行实际的文件导出操作
  Future<void> _executeActualExport(String data, String format, String exportRange) async {
    try {
      // 获取文件扩展名
      String extension = format == 'Excel' ? 'csv' : 'pdf';
      
      // 生成文件名
      String fileName = '审核记录_${DateTime.now().toString().substring(0, 19).replaceAll(RegExp(r'[:\s-]'), '_')}.$extension';
      
      // 使用FilePicker让用户选择保存位置
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
        initialDirectory: '',
      );
      
      if (selectedDirectory != null) {
        // 创建完整的文件路径
        String filePath = '$selectedDirectory\\$fileName';
        
        // 将数据写入文件，明确指定UTF-8编码并添加BOM，防止中文乱码
        final file = File(filePath);
        // 添加UTF-8 BOM以确保Excel等软件正确识别编码
        final utf8Bom = utf8.decode([0xEF, 0xBB, 0xBF]);
        await file.writeAsString('$utf8Bom$data', encoding: utf8);
        
        // 显示保存成功提示
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        // 清除所有现有提示，确保新提示能正确显示和消失
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('文件已成功保存到 $filePath'),
            backgroundColor: const Color(0xFF13ec5b),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '打开文件夹',
              onPressed: () {
                // 打开保存位置
                _openDirectory(selectedDirectory);
              },
            ),
          ),
        );
      } else {
        // 用户取消了保存
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('已取消保存'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 处理保存失败
      print('保存文件失败：$e');
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('保存文件失败：$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 打开目录
  void _openDirectory(String path) {
    // 使用open_file包打开目录
    try {
      OpenFile.open(path);
    } catch (e) {
      print('打开目录失败：$e');
    }
  }

  /// 模拟下载操作
  void _simulateDownload(String data, String format) {
    // 执行实际的导出操作
    _executeActualExport(data, format, '模拟导出');
  }

  /// 构建导出选项项
  Widget _buildExportOptionItem(String label, {bool isButton = false, bool isSelected = false, Function(String value)? onChanged, String? groupValue}) {
    if (isButton) {
      return ElevatedButton(
        onPressed: () {
          // 选择导出格式
          if (onChanged != null) {
            onChanged(label);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF13ec5b) : Colors.transparent,
          foregroundColor: isSelected ? const Color(0xFF102216) : const Color(0xFF13ec5b),
          side: BorderSide(color: const Color(0xFF13ec5b).withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Text(label),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Radio(
            value: label,
            groupValue: groupValue,
            onChanged: (value) {
              // 选择导出范围
              if (value != null && onChanged != null) {
                onChanged(value);
              }
            },
            activeColor: const Color(0xFF13ec5b),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示更多选项
  void _showMoreOptions() {
    // 弹出更多选项菜单
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2C20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => _buildMoreOptionsModal(),
    );
  }

  /// 构建更多选项模态框
  Widget _buildMoreOptionsModal() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          const Text(
            '更多选项',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // 选项列表
          Column(
            children: [
              _buildMoreOptionItem('权限说明'),
              _buildMoreOptionItem('操作日志'),
              _buildMoreOptionItem('设置'),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 构建更多选项项
  Widget _buildMoreOptionItem(String label) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (label == '权限说明') {
          // 显示权限说明
          _showPermissionInfo();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF2A4532)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示权限说明
  void _showPermissionInfo() {
    // 弹出权限说明对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '权限说明',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13ec5b),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      permissionDescriptions[_currentPermission]!, 
                      style: const TextStyle(
                        color: const Color(0xFF102216),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 遍历所有权限，显示详细说明
              for (var permission in AdminPermission.values) ...[
                Text(
                  '${permissionDescriptions[permission]}权限:',
                  style: TextStyle(
                    color: permission == _currentPermission ? Colors.white : Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  permissionFeatures[permission]!.map((feature) => '• $feature').join('\n'),
                  style: TextStyle(
                    color: permission == _currentPermission ? Colors.white : Colors.grey.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 当前管理员权限特殊提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF102216),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF13ec5b), width: 1),
                ),
                child: Text(
                  '当前管理员为 ${permissionDescriptions[_currentPermission]}，拥有以上${permissionFeatures[_currentPermission]!.length}项权限。',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 关闭按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13ec5b),
                    foregroundColor: const Color(0xFF102216),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化商品规格
  String _formatSpecs(List<StarProductSpec>? specs) {
    if (specs == null || specs.isEmpty) {
      return '暂无规格信息';
    }
    
    return specs.map((spec) {
      return '${spec.name}: ${spec.values.join(', ')}';
    }).join('; ');
  }

  /// 更新全选状态
  void _updateAllSelectedState() {
    // 获取所有待审核商品
    List<StarProduct> allProducts = _getAllProducts();
    List<StarProduct> pendingProducts = allProducts.where((p) => p.status == 'pending').toList();
    
    // 如果没有待审核商品，全选状态为false
    if (pendingProducts.isEmpty) {
      _isAllSelected = false;
      return;
    }
    
    // 检查是否所有待审核商品都被选中
    bool allSelected = true;
    for (var product in pendingProducts) {
      if (!_selectedProductIds.contains(product.id)) {
        allSelected = false;
        break;
      }
    }
    
    setState(() {
      _isAllSelected = allSelected;
    });
  }
  
  /// 获取审核状态颜色
  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'pending':
        return theme.colorScheme.error;
      case 'approved':
        return theme.colorScheme.primary;
      case 'rejected':
        return theme.colorScheme.secondary;
      case 'resubmitted':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
  
  /// 获取审核状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待审核';
      case 'approved':
        return '审核通过';
      case 'rejected':
        return '审核驳回';
      case 'resubmitted':
        return '重新提交';
      default:
        return '未知状态';
    }
  }
  
  /// 构建驳回模态框
  Widget _buildRejectModal(BuildContext context, StarProduct product) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '驳回商品',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.grey,
                ),
                onPressed: () {
                  // 关闭模态框
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 驳回原因
          const Text(
            '选择驳回原因',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildReasonChip('商品信息不符', isSelected: true),
              _buildReasonChip('含有违规内容'),
              _buildReasonChip('图片模糊/质量低'),
              _buildReasonChip('价格异常'),
              _buildReasonChip('类目错误'),
            ],
          ),
          const SizedBox(height: 20),
          // 详细说明
          const Text(
            '详细说明 (必填)',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextField(
                maxLines: 5,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF13ec5b)),
                  ),
                  hintText: '请输入具体驳回原因，以便商家修改...',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.all(16),
                ),
                controller: TextEditingController(
                  text: '商品的主图与实际描述的规格不符，请核实后重新上传正确的图片。',
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '32/200',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 提示信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '驳回后，商品将退回至商家草稿箱，商家修改后需重新提交审核。',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 确认按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // 确认驳回
                _rejectProduct(product);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 18),
                  const SizedBox(width: 8),
                  const Text('确认驳回'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
  }

  /// 驳回单个商品
  void _rejectProduct(StarProduct product) async {
    // 生成审核日志
    final auditLog = AuditLog(
      operator: 'admin',
      time: DateTime.now(),
      result: '审核驳回',
      reason: '商品的主图与实际描述的规格不符，请核实后重新上传正确的图片。',
      remark: '',
    );
    
    try {
      // 创建新的商品对象，更新状态
      final updatedProduct = StarProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        image: product.image,
        mainImages: product.mainImages,
        productCode: product.productCode,
        points: product.points,
        costPrice: product.costPrice,
        stock: product.stock,
        categoryId: product.categoryId,
        brand: product.brand,
        tags: product.tags,
        categoryPath: product.categoryPath,
        isActive: product.isActive,
        isDeleted: product.isDeleted,
        status: 'rejected',
        shippingTemplateId: product.shippingTemplateId,
        isPreSale: product.isPreSale,
        preSaleEndTime: product.preSaleEndTime,
        releaseTime: product.releaseTime,
        scheduledReleaseTime: product.scheduledReleaseTime,
        sales7Days: product.sales7Days,
        totalSales: product.totalSales,
        visitors: product.visitors,
        conversionRate: product.conversionRate,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: product.deletedAt,
        skus: product.skus,
        specs: product.specs,
        video: product.video,
        videoCover: product.videoCover,
        videoDescription: product.videoDescription,
        detailImages: product.detailImages,
        detail: product.detail,
        weight: product.weight,
        volume: product.volume,
        originalPrice: product.originalPrice,
        price: product.price,
        memberPrice: product.memberPrice,
        shippingTime: product.shippingTime,
        shippingAddress: product.shippingAddress,
        returnPolicy: product.returnPolicy,
        sortWeight: product.sortWeight,
        isLimitedPurchase: product.isLimitedPurchase,
        limitQuantity: product.limitQuantity,
        internalNote: product.internalNote,
        seoTitle: product.seoTitle,
        seoKeywords: product.seoKeywords,
      );
      
      // 保存到数据库
      await _databaseService.updateStarProduct(updatedProduct);
      
      // 更新本地状态
      setState(() {
        // 从待审核列表中移除
        _pendingProducts.removeWhere((p) => p.id == product.id);
        // 添加到已驳回列表
        _rejectedProducts.add(updatedProduct);
        // 如果当前选中的是该商品，更新选中状态
        if (_selectedProduct?.id == product.id) {
          _selectedProduct = updatedProduct;
        }
        // 从选中列表中移除
        _selectedProductIds.remove(product.id);
        // 更新全选状态
        _updateAllSelectedState();
        // 存储审核日志
        if (product.id != null) {
          _saveAuditLog(product.id!, auditLog);
        }
      });
      
      // 显示审核驳回成功提示
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('商品「${product.name}」审核驳回，已同步至平台商品库'),
          backgroundColor: const Color(0xFF13ec5b),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('审核驳回商品失败: $e');
      // 显示审核失败提示
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('商品「${product.name}」审核驳回失败，请重试'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// 构建驳回原因标签
  Widget _buildReasonChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.1) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF13ec5b) : Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}

/// 商品审核详情页面
class ProductReviewDetailPage extends StatelessWidget {
  final StarProduct product;

  const ProductReviewDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品图片
                Container(
                  width: double.infinity,
                  height: 375,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: ImageLoaderService.getImageProvider(product.image),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Text(
                          '1/5',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 商品信息
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '¥${product.costPrice}',
                            style: const TextStyle(
                              color: Color(0xFF13ec5b),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '¥${product.originalPrice}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2A1C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.pending,
                              size: 16,
                              color: Colors.yellow,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '当前状态: 待审核',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 分隔线
                      Container(
                        height: 1,
                        color: const Color(0xFF2A4532),
                      ),
                      const SizedBox(height: 16),
                      // 商家信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: ImageLoaderService.getImageProvider(product.image),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${product.brand} 官方旗舰店',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: List.generate(5, (index) => const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.yellow,
                                    )),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // 查看店铺
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: const Color(0xFF13ec5b),
                              side: BorderSide(color: const Color(0xFF13ec5b).withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            child: const Text('查看店铺'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 分隔线
                      Container(
                        height: 1,
                        color: const Color(0xFF2A4532),
                      ),
                      const SizedBox(height: 16),
                      // 规格参数
                      const Text(
                        '规格参数',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2C20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A4532)),
                        ),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3,
                          children: [
                            _buildSpecItem('品牌', product.brand ?? ''),
                            _buildSpecItem('型号', product.productCode),
                            _buildSpecItem('存储', '256GB'),
                            _buildSpecItem('发货地', '上海保税区'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 商品详情
                      const Text(
                        '商品详情',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.description ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 详情图片
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 150,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: ImageLoaderService.getImageProvider(product.image),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 150,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: ImageLoaderService.getImageProvider(product.image),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 顶部导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF102216),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    '商品详情',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    onPressed: () {
                      // 更多操作
                    },
                  ),
                ],
              ),
            ),
          ),
          // 底部操作栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF102216),
                border: Border(top: BorderSide(color: const Color(0xFF2A4532))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // 驳回商品
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF1A2C20),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          builder: (context) => _buildRejectModal(context),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close, size: 18),
                          const SizedBox(width: 8),
                          const Text('驳回'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        // 审核通过
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ec5b),
                        foregroundColor: const Color(0xFF102216),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          const Text('审核通过'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建规格项
  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建驳回模态框
  Widget _buildRejectModal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '驳回商品',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.grey,
                ),
                onPressed: () {
                  // 关闭模态框
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 驳回原因
          const Text(
            '选择驳回原因',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildReasonChip('商品信息不符', isSelected: true),
              _buildReasonChip('含有违规内容'),
              _buildReasonChip('图片模糊/质量低'),
              _buildReasonChip('价格异常'),
              _buildReasonChip('类目错误'),
            ],
          ),
          const SizedBox(height: 20),
          // 详细说明
          const Text(
            '详细说明 (必填)',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextField(
                maxLines: 5,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF13ec5b)),
                  ),
                  hintText: '请输入具体驳回原因，以便商家修改...',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.all(16),
                ),
                controller: TextEditingController(
                  text: '商品的主图与实际描述的规格不符，请核实后重新上传正确的图片。',
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '32/200',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 提示信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '驳回后，商品将退回至商家草稿箱，商家修改后需重新提交审核。',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 确认按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // 确认驳回
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 18),
                  const SizedBox(width: 8),
                  const Text('确认驳回'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
  }

  /// 构建驳回原因标签
  Widget _buildReasonChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.1) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF13ec5b).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF13ec5b) : Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
