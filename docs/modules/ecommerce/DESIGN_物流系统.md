# DESIGN_物流系统.md

## 整体架构图

```mermaid
graph TB
    subgraph Client["客户端"]
        OD[order_detail_page.dart<br/>订单详情+物流入口]
        LTP[logistics_tracking_page.dart<br/>物流跟踪时间轴]
        ASP[after_sales_page.dart<br/>售后+退货物流]
    end

    subgraph Merchant["商家端"]
        MOM[merchant_order_management_page.dart<br/>订单管理+一键发货]
        MOD[merchant_order_detail_page.dart<br/>订单详情+发货操作]
        SD[shipping_dialog.dart<br/>发货对话框NEW]
        LP[logistics_page.dart<br/>物流公司管理]
    end

    subgraph Services["服务层"]
        PDS[ProductDatabaseService<br/>订单/物流CRUD]
        NS[NotificationService<br/>发货通知]
    end

    subgraph DB["数据库 (moment_keep_products.db)"]
        O[orders表]
        LC[logistics_companies表]
        LT[logistics_tracks表]
        RL[return_logistics表NEW]
    end

    MOD --> SD
    MOD --> PDS
    MOM --> PDS
    SD --> PDS
    OD --> LTP
    OD --> ASP
    LTP --> PDS
    ASP --> PDS
    LP --> PDS
    PDS --> O
    PDS --> LC
    PDS --> LT
    PDS --> RL
    NS --> PDS
```

## 数据流设计

```mermaid
sequenceDiagram
    participant M as 商家
    participant SD as ShippingDialog
    participant PDS as ProductDatabaseService
    participant DB as SQLite
    participant C as 客户端

    M->>SD: 点击"发货"按钮
    alt 实物商品
        SD->>SD: 选择物流公司+填运单号
        SD->>PDS: insertLogisticsTrack(ship节点)
        PDS->>DB: INSERT logistics_tracks
        SD->>PDS: updateOrder(status=shipped)
        PDS->>DB: UPDATE orders
        SD->>PDS: insertLogisticsTrack(pick节点-模拟)
        Note over SD: 自动添加揽收/运输/派送节点
        SD->>DB: 批量INSERT logistics_tracks
    else 虚拟商品
        SD->>PDS: updateOrder(status=shipped)
        SD->>PDS: updateOrder(status=completed)
        PDS->>DB: UPDATE orders
    end
    SD-->>M: 发货成功提示
    C->>PDS: 查看物流跟踪
    PDS->>DB: SELECT logistics_tracks
    DB-->>C: 物流时间轴数据
```

## 模块设计

### 1. ShippingDialog (新建)
- 文件: `lib/presentation/components/shipping_dialog.dart`
- 职责: 统一的发货操作入口
- 模式: 根据 `isElectronic` 切换实物/虚拟两种UI
- 实物模式: 物流公司下拉 + 运单号输入 + 发货按钮
- 虚拟模式: "确认无需物流发货"提示 + 确认按钮

### 2. ReturnLogisticsDialog (新建)
- 文件: `lib/presentation/components/return_logistics_dialog.dart`
- 职责: 退货物流录入
- 内容: 物流公司选择 + 退货运单号 + 提交按钮

### 3. 物流跟踪页优化 (修改)
- 文件: `lib/presentation/pages/logistics_tracking_page.dart`
- 优化: 进度条、节点状态图标、自动更新

### 4. 数据库服务扩展 (修改)
- 文件: `lib/services/product_database_service.dart`
- 新增: `return_logistics` CRUD, 物流节点批量插入