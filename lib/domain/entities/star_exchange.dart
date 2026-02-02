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