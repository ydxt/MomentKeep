

class StarCategory {
  final int? id;
  final String name;
  final String? description;
  final String? icon;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  StarCategory({
    this.id,
    required this.name,
    this.description,
    this.icon,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory StarCategory.fromMap(Map<String, dynamic> map) {
    return StarCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: map['icon'],
      sortOrder: map['sort_order'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// SKU实体类
class StarProductSku {
  final int? id;
  final int productId;
  final String skuCode;
  final Map<String, dynamic> specValues; // 规格值，如 {"颜色": "红色", "尺寸": "L"}
  final int price; // 现金价格
  final int points; // 积分价格
  final int hybridPrice; // 混合支付的现金部分
  final int hybridPoints; // 混合支付的积分部分
  final int costPrice;
  final int stock;
  final String? image;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  
  // 支付方式相关字段
  final bool supportPointsPayment;
  final bool supportCashPayment;
  final bool supportHybridPayment;

  StarProductSku({
    this.id,
    required this.productId,
    required this.skuCode,
    required this.specValues,
    required this.price,
    required this.points,
    this.hybridPrice = 0,
    this.hybridPoints = 0,
    required this.costPrice,
    required this.stock,
    this.image,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.supportPointsPayment = true,
    this.supportCashPayment = true,
    this.supportHybridPayment = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'sku_code': skuCode,
      'spec_values': specValues,
      'price': price,
      'points': points,
      'hybrid_price': hybridPrice,
      'hybrid_points': hybridPoints,
      'cost_price': costPrice,
      'stock': stock,
      'image': image,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_deleted': isDeleted ? 1 : 0,
      'support_points_payment': supportPointsPayment ? 1 : 0,
      'support_cash_payment': supportCashPayment ? 1 : 0,
      'support_hybrid_payment': supportHybridPayment ? 1 : 0,
    };
  }

  factory StarProductSku.fromMap(Map<String, dynamic> map) {
    return StarProductSku(
      id: map['id'],
      productId: map['product_id'],
      skuCode: map['sku_code'],
      specValues: Map<String, dynamic>.from(map['spec_values']),
      price: map['price'],
      points: map['points'] ?? 0,
      hybridPrice: map['hybrid_price'] ?? 0,
      hybridPoints: map['hybrid_points'] ?? 0,
      costPrice: map['cost_price'],
      stock: map['stock'],
      image: map['image'],
      sortOrder: map['sort_order'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      isDeleted: map['is_deleted'] == 1,
      supportPointsPayment: map['support_points_payment'] == 1,
      supportCashPayment: map['support_cash_payment'] == 1,
      supportHybridPayment: map['support_hybrid_payment'] == 1,
    );
  }
}

/// 商品规格实体类
class StarProductSpec {
  final int? id;
  final int productId;
  final String name;
  final List<String> values;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  StarProductSpec({
    this.id,
    required this.productId,
    required this.name,
    required this.values,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'values': values.join(','),
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory StarProductSpec.fromMap(Map<String, dynamic> map) {
    return StarProductSpec(
      id: map['id'],
      productId: map['product_id'],
      name: map['name'],
      values: (map['values'] as String).split(','),
      sortOrder: map['sort_order'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 运费模板实体类
class StarShippingTemplate {
  final int? id;
  final String name;
  final String type; // 'free' 包邮, 'weight' 按重量, 'quantity' 按件数, 'region' 按地区
  final Map<String, dynamic> config;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  StarShippingTemplate({
    this.id,
    required this.name,
    required this.type,
    required this.config,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'config': config,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory StarShippingTemplate.fromMap(Map<String, dynamic> map) {
    return StarShippingTemplate(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      config: Map<String, dynamic>.from(map['config']),
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

class StarProduct {
  final int? id;
  final String name;
  final String? description;
  final String image;
  final List<String> mainImages; // 主图列表
  final String productCode; // 商品编码，唯一标识
  final int points; // 积分价格
  final int hybridPoints; // 混合支付的积分部分
  final int hybridPrice; // 混合支付的现金部分
  final int costPrice; // 成本价
  final int stock;
  final int categoryId;
  final int? merchantId; // 商家ID
  final String? brand; // 品牌
  final List<String> tags; // 商品标签
  final String? categoryPath; // 分类路径，如 "1>2>3"
  final bool isActive;
  final bool isDeleted;
  final String status; // 商品状态：draft(草稿), pending(审核中), approved(审核通过), rejected(审核驳回), active(已上架), inactive(已下架), violated(违规下架)
  final int? shippingTemplateId; // 运费模板ID
  final bool isPreSale; // 是否预售
  final DateTime? preSaleEndTime; // 预售结束时间
  final DateTime? releaseTime; // 上架时间
  final DateTime? scheduledReleaseTime; // 定时上架时间
  final int sales7Days; // 近7天销量
  final int totalSales; // 累计销量
  final int visitors; // 访客数
  final double conversionRate; // 转化率
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<StarProductSku>? skus; // SKU列表
  final List<StarProductSpec>? specs; // 规格列表
  
  // 新增字段
  final String? video; // 视频链接
  final String? videoCover; // 视频封面
  final String? videoDescription; // 视频描述
  final List<String> detailImages; // 详情图列表
  final String? detail; // 商品详情
  final String? weight; // 重量
  final String? volume; // 体积
  final int originalPrice; // 原价
  final int price; // 现金售价
  final int memberPrice; // 会员价
  final String? shippingTime; // 发货时间
  final String? shippingAddress; // 发货地址
  final String? returnPolicy; // 退货政策
  final int sortWeight; // 排序权重
  final bool isLimitedPurchase; // 是否限购
  final int limitQuantity; // 限购数量
  final String? internalNote; // 内部备注
  final String? seoTitle; // SEO标题
  final String? seoKeywords; // SEO关键词
  
  // 支付方式相关字段
  final bool supportPointsPayment; // 是否支持积分支付
  final bool supportCashPayment; // 是否支持现金支付
  final bool supportHybridPayment; // 是否支持混合支付

  StarProduct({
    this.id,
    required this.name,
    this.description,
    required this.image,
    this.mainImages = const [],
    required this.productCode,
    required this.points,
    this.hybridPoints = 0,
    this.hybridPrice = 0,
    required this.costPrice,
    required this.stock,
    required this.categoryId,
    this.merchantId,
    this.brand,
    this.tags = const [],
    this.categoryPath,
    this.isActive = true,
    this.isDeleted = false,
    this.status = 'draft',
    this.shippingTemplateId,
    this.isPreSale = false,
    this.preSaleEndTime,
    this.releaseTime,
    this.scheduledReleaseTime,
    this.sales7Days = 0,
    this.totalSales = 0,
    this.visitors = 0,
    this.conversionRate = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.skus,
    this.specs,
    
    // 新增字段
    this.video,
    this.videoCover,
    this.videoDescription,
    this.detailImages = const [],
    this.detail,
    this.weight,
    this.volume,
    this.originalPrice = 0,
    this.price = 0,
    this.memberPrice = 0,
    this.shippingTime,
    this.shippingAddress,
    this.returnPolicy,
    this.sortWeight = 0,
    this.isLimitedPurchase = false,
    this.limitQuantity = 1,
    this.internalNote,
    this.seoTitle,
    this.seoKeywords,
    
    // 支付方式相关字段默认值
    this.supportPointsPayment = true,
    this.supportCashPayment = true,
    this.supportHybridPayment = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'main_images': mainImages.join(','),
      'product_code': productCode,
      'points': points,
      'hybrid_points': hybridPoints,
      'hybrid_price': hybridPrice,
      'cost_price': costPrice,
      'stock': stock,
      'category_id': categoryId,
      'merchant_id': merchantId,
      'brand': brand,
      'tags': tags.join(','),
      'category_path': categoryPath,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'status': status,
      'shipping_template_id': shippingTemplateId,
      'is_pre_sale': isPreSale ? 1 : 0,
      'pre_sale_end_time': preSaleEndTime?.millisecondsSinceEpoch,
      'release_time': releaseTime?.millisecondsSinceEpoch,
      'scheduled_release_time': scheduledReleaseTime?.millisecondsSinceEpoch,
      'sales_7_days': sales7Days,
      'total_sales': totalSales,
      'visitors': visitors,
      'conversion_rate': conversionRate,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      
      // 新增字段
      'video': video,
      'video_cover': videoCover,
      'video_description': videoDescription,
      'detail_images': detailImages.join(','),
      'detail': detail,
      'weight': weight,
      'volume': volume,
      'original_price': originalPrice,
      'price': price,
      'member_price': memberPrice,
      'shipping_time': shippingTime,
      'shipping_address': shippingAddress,
      'return_policy': returnPolicy,
      'sort_weight': sortWeight,
      'is_limited_purchase': isLimitedPurchase ? 1 : 0,
      'limit_quantity': limitQuantity,
      'internal_note': internalNote,
      'seo_title': seoTitle,
      'seo_keywords': seoKeywords,
      
      // 支付方式相关字段
      'support_points_payment': supportPointsPayment ? 1 : 0,
      'support_cash_payment': supportCashPayment ? 1 : 0,
      'support_hybrid_payment': supportHybridPayment ? 1 : 0,
    };
  }

  factory StarProduct.fromMap(Map<String, dynamic> map) {
    return StarProduct(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      image: map['image'],
      mainImages: map['main_images'] != null ? (map['main_images'] as String).split(',') : [],
      productCode: map['product_code'] ?? '',
      points: map['points'],
      hybridPoints: map['hybrid_points'] ?? 0,
      hybridPrice: map['hybrid_price'] ?? 0,
      costPrice: map['cost_price'] ?? 0,
      stock: map['stock'],
      categoryId: map['category_id'],
      merchantId: map['merchant_id'],
      brand: map['brand'],
      tags: map['tags'] != null ? (map['tags'] as String).split(',') : [],
      categoryPath: map['category_path'],
      isActive: map['is_active'] == 1,
      isDeleted: map['is_deleted'] == 1,
      status: map['status'] ?? 'draft',
      shippingTemplateId: map['shipping_template_id'],
      isPreSale: map['is_pre_sale'] == 1,
      preSaleEndTime: map['pre_sale_end_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['pre_sale_end_time']) : null,
      releaseTime: map['release_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['release_time']) : null,
      scheduledReleaseTime: map['scheduled_release_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_release_time']) : null,
      sales7Days: map['sales_7_days'] ?? 0,
      totalSales: map['total_sales'] ?? 0,
      visitors: map['visitors'] ?? 0,
      conversionRate: (map['conversion_rate'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      deletedAt: map['deleted_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['deleted_at']) : null,
      
      // 新增字段
      video: map['video'],
      videoCover: map['video_cover'],
      videoDescription: map['video_description'],
      detailImages: map['detail_images'] != null ? (map['detail_images'] as String).split(',') : [],
      detail: map['detail'],
      weight: map['weight'],
      volume: map['volume'],
      originalPrice: map['original_price'] ?? 0,
      price: map['price'] ?? 0,
      memberPrice: map['member_price'] ?? 0,
      shippingTime: map['shipping_time'],
      shippingAddress: map['shipping_address'],
      returnPolicy: map['return_policy'],
      sortWeight: map['sort_weight'] ?? 0,
      isLimitedPurchase: map['is_limited_purchase'] == 1,
      limitQuantity: map['limit_quantity'] ?? 1,
      internalNote: map['internal_note'],
      seoTitle: map['seo_title'],
      seoKeywords: map['seo_keywords'],
      
      // 支付方式相关字段
      supportPointsPayment: map['support_points_payment'] == 1,
      supportCashPayment: map['support_cash_payment'] == 1,
      supportHybridPayment: map['support_hybrid_payment'] == 1,
    );
  }
}

/// 账单实体类
class Bill {
  final String id;
  final String userId;
  final int balance;
  final int income;
  final int expense;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bill({
    required this.id,
    required this.userId,
    required this.balance,
    required this.income,
    required this.expense,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'income': income,
      'expense': expense,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'],
      userId: map['user_id'],
      balance: map['balance'],
      income: map['income'],
      expense: map['expense'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 账单明细实体类
class BillItem {
  final String id;
  final String userId;
  final String billId;
  final int amount;
  final String type; // 'income' 或 'expense'
  final String transactionType; // 具体交易类型，如 'reward', 'exchange', 'refund' 等
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? relatedId; // 关联的其他表ID，如订单ID、退款申请ID等

  BillItem({
    required this.id,
    required this.userId,
    required this.billId,
    required this.amount,
    required this.type,
    required this.transactionType,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.relatedId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'bill_id': billId,
      'amount': amount,
      'type': type,
      'transaction_type': transactionType,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'related_id': relatedId,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'],
      userId: map['user_id'],
      billId: map['bill_id'],
      amount: map['amount'],
      type: map['type'],
      transactionType: map['transaction_type'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      relatedId: map['related_id'],
    );
  }
}

// ==========================================
// 优惠券相关实体
// ==========================================

/// 优惠券实体类
class Coupon {
  final int? id;
  final String name;
  final String code;
  final String type; // 'fixed' 固定金额, 'percentage' 百分比, 'shipping' 免邮
  final int? value; // 优惠值（固定金额或百分比）
  final int? minAmount; // 最低使用金额
  final int? maxDiscount; // 最大优惠金额
  final int totalCount; // 总数量
  final int usedCount; // 已使用数量
  final DateTime? startTime; // 开始时间
  final DateTime? endTime; // 结束时间
  final int? validDays; // 有效天数（领取后计算）
  final List<int>? categoryIds; // 适用分类ID列表
  final List<int>? productIds; // 适用商品ID列表
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Coupon({
    this.id,
    required this.name,
    required this.code,
    required this.type,
    this.value,
    this.minAmount,
    this.maxDiscount,
    required this.totalCount,
    this.usedCount = 0,
    this.startTime,
    this.endTime,
    this.validDays,
    this.categoryIds,
    this.productIds,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'value': value,
      'min_amount': minAmount,
      'max_discount': maxDiscount,
      'total_count': totalCount,
      'used_count': usedCount,
      'start_time': startTime?.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'valid_days': validDays,
      'category_ids': categoryIds?.join(','),
      'product_ids': productIds?.join(','),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      type: map['type'],
      value: map['value'],
      minAmount: map['min_amount'],
      maxDiscount: map['max_discount'],
      totalCount: map['total_count'],
      usedCount: map['used_count'] ?? 0,
      startTime: map['start_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['end_time']) : null,
      validDays: map['valid_days'],
      categoryIds: map['category_ids'] != null ? (map['category_ids'] as String).split(',').map(int.parse).toList() : null,
      productIds: map['product_ids'] != null ? (map['product_ids'] as String).split(',').map(int.parse).toList() : null,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 用户优惠券实体类
class UserCoupon {
  final int? id;
  final String userId;
  final int couponId;
  final String? orderId; // 使用的订单ID
  final DateTime? usedAt; // 使用时间
  final DateTime createdAt;
  final DateTime? expiresAt; // 过期时间
  final String status; // 'unused' 未使用, 'used' 已使用, 'expired' 已过期

  UserCoupon({
    this.id,
    required this.userId,
    required this.couponId,
    this.orderId,
    this.usedAt,
    required this.createdAt,
    this.expiresAt,
    this.status = 'unused',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'coupon_id': couponId,
      'order_id': orderId,
      'used_at': usedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory UserCoupon.fromMap(Map<String, dynamic> map) {
    return UserCoupon(
      id: map['id'],
      userId: map['user_id'],
      couponId: map['coupon_id'],
      orderId: map['order_id'],
      usedAt: map['used_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['used_at']) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      expiresAt: map['expires_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['expires_at']) : null,
      status: map['status'] ?? 'unused',
    );
  }
}

// ==========================================
// 红包相关实体
// ==========================================

/// 红包实体类
class RedPacket {
  final int? id;
  final String name;
  final String type; // 'random' 随机, 'fixed' 固定
  final int totalAmount;
  final int totalCount;
  final int receivedCount;
  final int? minAmount;
  final int? maxAmount;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RedPacket({
    this.id,
    required this.name,
    required this.type,
    required this.totalAmount,
    required this.totalCount,
    this.receivedCount = 0,
    this.minAmount,
    this.maxAmount,
    this.startTime,
    this.endTime,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'total_amount': totalAmount,
      'total_count': totalCount,
      'received_count': receivedCount,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'start_time': startTime?.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory RedPacket.fromMap(Map<String, dynamic> map) {
    return RedPacket(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      totalAmount: map['total_amount'],
      totalCount: map['total_count'],
      receivedCount: map['received_count'] ?? 0,
      minAmount: map['min_amount'],
      maxAmount: map['max_amount'],
      startTime: map['start_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['end_time']) : null,
      description: map['description'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 红包领取记录实体类
class RedPacketClaim {
  final int? id;
  final int redPacketId;
  final String userId;
  final int amount;
  final DateTime claimedAt;

  RedPacketClaim({
    this.id,
    required this.redPacketId,
    required this.userId,
    required this.amount,
    required this.claimedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'red_packet_id': redPacketId,
      'user_id': userId,
      'amount': amount,
      'claimed_at': claimedAt.millisecondsSinceEpoch,
    };
  }

  factory RedPacketClaim.fromMap(Map<String, dynamic> map) {
    return RedPacketClaim(
      id: map['id'],
      redPacketId: map['red_packet_id'],
      userId: map['user_id'],
      amount: map['amount'],
      claimedAt: DateTime.fromMillisecondsSinceEpoch(map['claimed_at']),
    );
  }
}

// ==========================================
// 购物卡相关实体
// ==========================================

/// 购物卡实体类
class ShoppingCard {
  final int? id;
  final String cardNo;
  final String name;
  final int totalAmount;
  final int balance;
  final String? password;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String status; // 'active' 可用, 'used' 已用完, 'expired' 已过期, 'inactive' 未激活
  final DateTime? activatedAt;
  final String? userId; // 绑定的用户ID
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingCard({
    this.id,
    required this.cardNo,
    required this.name,
    required this.totalAmount,
    required this.balance,
    this.password,
    this.validFrom,
    this.validTo,
    this.status = 'inactive',
    this.activatedAt,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'card_no': cardNo,
      'name': name,
      'total_amount': totalAmount,
      'balance': balance,
      'password': password,
      'valid_from': validFrom?.millisecondsSinceEpoch,
      'valid_to': validTo?.millisecondsSinceEpoch,
      'status': status,
      'activated_at': activatedAt?.millisecondsSinceEpoch,
      'user_id': userId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ShoppingCard.fromMap(Map<String, dynamic> map) {
    return ShoppingCard(
      id: map['id'],
      cardNo: map['card_no'],
      name: map['name'],
      totalAmount: map['total_amount'],
      balance: map['balance'],
      password: map['password'],
      validFrom: map['valid_from'] != null ? DateTime.fromMillisecondsSinceEpoch(map['valid_from']) : null,
      validTo: map['valid_to'] != null ? DateTime.fromMillisecondsSinceEpoch(map['valid_to']) : null,
      status: map['status'] ?? 'inactive',
      activatedAt: map['activated_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['activated_at']) : null,
      userId: map['user_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 购物卡交易记录实体类
class ShoppingCardTransaction {
  final int? id;
  final int shoppingCardId;
  final String? orderId;
  final int amount;
  final String type; // 'consume' 消费, 'recharge' 充值, 'refund' 退款
  final int balanceBefore;
  final int balanceAfter;
  final String? description;
  final DateTime createdAt;

  ShoppingCardTransaction({
    this.id,
    required this.shoppingCardId,
    this.orderId,
    required this.amount,
    required this.type,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopping_card_id': shoppingCardId,
      'order_id': orderId,
      'amount': amount,
      'type': type,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ShoppingCardTransaction.fromMap(Map<String, dynamic> map) {
    return ShoppingCardTransaction(
      id: map['id'],
      shoppingCardId: map['shopping_card_id'],
      orderId: map['order_id'],
      amount: map['amount'],
      type: map['type'],
      balanceBefore: map['balance_before'],
      balanceAfter: map['balance_after'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

// ==========================================
// 地址相关实体
// ==========================================

/// 地址实体类
class Address {
  final int? id;
  final String userId;
  final String name;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detail;
  final String? postalCode;
  final bool isDefault;
  final String? tag; // 'home' 家, 'company' 公司, 'other' 其他
  final DateTime createdAt;
  final DateTime updatedAt;

  Address({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detail,
    this.postalCode,
    this.isDefault = false,
    this.tag,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$province$city$district$detail';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'province': province,
      'city': city,
      'district': district,
      'detail': detail,
      'postal_code': postalCode,
      'is_default': isDefault ? 1 : 0,
      'tag': tag,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      phone: map['phone'],
      province: map['province'],
      city: map['city'],
      district: map['district'],
      detail: map['detail'],
      postalCode: map['postal_code'],
      isDefault: map['is_default'] == 1,
      tag: map['tag'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

// ==========================================
// 会员等级相关实体
// ==========================================

/// 会员等级实体类
class MemberLevel {
  final int? id;
  final String name;
  final int minPoints; // 最低积分要求
  final double discount; // 折扣（0.0-1.0）
  final int pointsBonus; // 积分加成比例（%）
  final String? icon;
  final String? privileges; // 权益描述
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemberLevel({
    this.id,
    required this.name,
    required this.minPoints,
    this.discount = 1.0,
    this.pointsBonus = 0,
    this.icon,
    this.privileges,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'min_points': minPoints,
      'discount': discount,
      'points_bonus': pointsBonus,
      'icon': icon,
      'privileges': privileges,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory MemberLevel.fromMap(Map<String, dynamic> map) {
    return MemberLevel(
      id: map['id'],
      name: map['name'],
      minPoints: map['min_points'],
      discount: (map['discount'] as num).toDouble(),
      pointsBonus: map['points_bonus'] ?? 0,
      icon: map['icon'],
      privileges: map['privileges'],
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

// ==========================================
// 物流相关实体
// ==========================================

/// 物流公司实体类
class LogisticsCompany {
  final int? id;
  final String name;
  final String code;
  final String? website;
  final String? phone;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  LogisticsCompany({
    this.id,
    required this.name,
    required this.code,
    this.website,
    this.phone,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'website': website,
      'phone': phone,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory LogisticsCompany.fromMap(Map<String, dynamic> map) {
    return LogisticsCompany(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      website: map['website'],
      phone: map['phone'],
      isActive: map['is_active'] == 1,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

/// 物流跟踪记录实体类
class LogisticsTrack {
  final int? id;
  final String orderId;
  final int? logisticsCompanyId;
  final String? trackingNumber;
  final String status; // 'created' 已创建, 'picked' 已揽收, 'transporting' 运输中, 'delivering' 派送中, 'delivered' 已签收, 'exception' 异常
  final String description;
  final String? location;
  final DateTime trackTime;
  final DateTime createdAt;

  LogisticsTrack({
    this.id,
    required this.orderId,
    this.logisticsCompanyId,
    this.trackingNumber,
    required this.status,
    required this.description,
    this.location,
    required this.trackTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'logistics_company_id': logisticsCompanyId,
      'tracking_number': trackingNumber,
      'status': status,
      'description': description,
      'location': location,
      'track_time': trackTime.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory LogisticsTrack.fromMap(Map<String, dynamic> map) {
    return LogisticsTrack(
      id: map['id'],
      orderId: map['order_id'],
      logisticsCompanyId: map['logistics_company_id'],
      trackingNumber: map['tracking_number'],
      status: map['status'],
      description: map['description'],
      location: map['location'],
      trackTime: DateTime.fromMillisecondsSinceEpoch(map['track_time']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

// ==========================================
// 支付记录相关实体
// ==========================================

/// 支付记录实体类
class PaymentRecord {
  final int? id;
  final String orderId;
  final String userId;
  final String paymentNo; // 支付流水号
  final int amount;
  final int pointsUsed;
  final int cashAmount;
  final String paymentMethod; // 'cash' 现金, 'points' 积分, 'hybrid' 混合, 'shopping_card' 购物卡
  final String? thirdPartyPaymentId; // 第三方支付ID
  final String status; // 'pending' 待支付, 'success' 支付成功, 'failed' 支付失败, 'refunded' 已退款
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentRecord({
    this.id,
    required this.orderId,
    required this.userId,
    required this.paymentNo,
    required this.amount,
    this.pointsUsed = 0,
    this.cashAmount = 0,
    required this.paymentMethod,
    this.thirdPartyPaymentId,
    this.status = 'pending',
    this.paidAt,
    this.refundedAt,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'payment_no': paymentNo,
      'amount': amount,
      'points_used': pointsUsed,
      'cash_amount': cashAmount,
      'payment_method': paymentMethod,
      'third_party_payment_id': thirdPartyPaymentId,
      'status': status,
      'paid_at': paidAt?.millisecondsSinceEpoch,
      'refunded_at': refundedAt?.millisecondsSinceEpoch,
      'failure_reason': failureReason,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'],
      orderId: map['order_id'],
      userId: map['user_id'],
      paymentNo: map['payment_no'],
      amount: map['amount'],
      pointsUsed: map['points_used'] ?? 0,
      cashAmount: map['cash_amount'] ?? 0,
      paymentMethod: map['payment_method'],
      thirdPartyPaymentId: map['third_party_payment_id'],
      status: map['status'] ?? 'pending',
      paidAt: map['paid_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['paid_at']) : null,
      refundedAt: map['refunded_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['refunded_at']) : null,
      failureReason: map['failure_reason'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

// ==========================================
// 库存记录相关实体
// ==========================================

/// 库存变动记录实体类
class StockRecord {
  final int? id;
  final int productId;
  final int? skuId;
  final String type; // 'in' 入库, 'out' 出库, 'adjust' 调整, 'order' 订单占用, 'return' 退货
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final String? relatedId; // 关联ID（订单ID、入库单ID等）
  final String? remark;
  final String operatorId;
  final DateTime createdAt;

  StockRecord({
    this.id,
    required this.productId,
    this.skuId,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.relatedId,
    this.remark,
    required this.operatorId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'sku_id': skuId,
      'type': type,
      'quantity': quantity,
      'stock_before': stockBefore,
      'stock_after': stockAfter,
      'related_id': relatedId,
      'remark': remark,
      'operator_id': operatorId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory StockRecord.fromMap(Map<String, dynamic> map) {
    return StockRecord(
      id: map['id'],
      productId: map['product_id'],
      skuId: map['sku_id'],
      type: map['type'],
      quantity: map['quantity'],
      stockBefore: map['stock_before'],
      stockAfter: map['stock_after'],
      relatedId: map['related_id'],
      remark: map['remark'],
      operatorId: map['operator_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

// ==========================================
// 商家相关实体
// ==========================================

/// 商家实体类
class Merchant {
  final int? id;
  final String userId;
  final String name;
  final String? logo;
  final String? description;
  final String? phone;
  final String? email;
  final String? address;
  final String status; // 'pending' 待审核, 'active' 正常营业, 'suspended' 已暂停, 'rejected' 已拒绝
  final double rating;
  final int totalSales;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Merchant({
    this.id,
    required this.userId,
    required this.name,
    this.logo,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.status = 'pending',
    this.rating = 0.0,
    this.totalSales = 0,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'logo': logo,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'status': status,
      'rating': rating,
      'total_sales': totalSales,
      'approved_at': approvedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Merchant.fromMap(Map<String, dynamic> map) {
    return Merchant(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      logo: map['logo'],
      description: map['description'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      status: map['status'] ?? 'pending',
      rating: (map['rating'] as num).toDouble(),
      totalSales: map['total_sales'] ?? 0,
      approvedAt: map['approved_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['approved_at']) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

// ==========================================
// 买家信用积分相关实体
// ==========================================

/// 买家信用积分实体类
class BuyerCreditScore {
  final String userId;
  final int creditScore;
  final String creditLevel;
  final int totalOrders;
  final int completedOrders;
  final double refundRate;
  final double onTimeRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  BuyerCreditScore({
    required this.userId,
    this.creditScore = 100,
    this.creditLevel = '良好',
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.refundRate = 0.0,
    this.onTimeRate = 100.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'credit_score': creditScore,
      'credit_level': creditLevel,
      'total_orders': totalOrders,
      'completed_orders': completedOrders,
      'refund_rate': refundRate,
      'on_time_rate': onTimeRate,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BuyerCreditScore.fromMap(Map<String, dynamic> map) {
    return BuyerCreditScore(
      userId: map['user_id'],
      creditScore: map['credit_score'] ?? 100,
      creditLevel: map['credit_level'] ?? '良好',
      totalOrders: map['total_orders'] ?? 0,
      completedOrders: map['completed_orders'] ?? 0,
      refundRate: (map['refund_rate'] as num).toDouble(),
      onTimeRate: (map['on_time_rate'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}

// ==========================================
// 积分统计相关实体
// ==========================================

/// 趋势数据点
class TrendDataPoint {
  final DateTime date;
  final double income;
  final double expense;

  TrendDataPoint({
    required this.date,
    required this.income,
    required this.expense,
  });
}

/// 积分统计数据
class PointsStatistics {
  final double totalIncome;
  final double totalExpense;
  final double netIncome;
  final int transactionCount;
  final List<TrendDataPoint> trendData;
  final Map<String, double> typeDistribution;
  final Map<String, double> incomeTypeDistribution;
  final Map<String, double> expenseTypeDistribution;

  PointsStatistics({
    required this.totalIncome,
    required this.totalExpense,
    required this.netIncome,
    required this.transactionCount,
    required this.trendData,
    required this.typeDistribution,
    required this.incomeTypeDistribution,
    required this.expenseTypeDistribution,
  });
}

// ==========================================
// 卖家信用积分相关实体
// ==========================================

/// 卖家信用积分实体类
class SellerCreditScore {
  final String userId;
  final int creditScore;
  final String creditLevel;
  final int totalOrders;
  final int completedOrders;
  final double refundRate;
  final double onTimeDeliveryRate;
  final double averageRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  SellerCreditScore({
    required this.userId,
    this.creditScore = 100,
    this.creditLevel = '良好',
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.refundRate = 0.0,
    this.onTimeDeliveryRate = 100.0,
    this.averageRating = 5.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'credit_score': creditScore,
      'credit_level': creditLevel,
      'total_orders': totalOrders,
      'completed_orders': completedOrders,
      'refund_rate': refundRate,
      'on_time_delivery_rate': onTimeDeliveryRate,
      'average_rating': averageRating,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SellerCreditScore.fromMap(Map<String, dynamic> map) {
    return SellerCreditScore(
      userId: map['user_id'],
      creditScore: map['credit_score'] ?? 100,
      creditLevel: map['credit_level'] ?? '良好',
      totalOrders: map['total_orders'] ?? 0,
      completedOrders: map['completed_orders'] ?? 0,
      refundRate: (map['refund_rate'] as num).toDouble(),
      onTimeDeliveryRate: (map['on_time_delivery_rate'] as num).toDouble(),
      averageRating: (map['average_rating'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }
}