# CONSENSUS_物流系统.md

## 一、明确需求

### 1.1 功能范围

**必须实现：**
1. 商家端"发货"操作 — 实物商品选物流公司+填运单号，虚拟商品点"无需物流"
2. 物流状态流转 — 发货(shipped)→揽收(picked)→运输中(transporting)→派送中(delivering)→签收(delivered)
3. 客户端物流跟踪UI — 时间轴展示完整物流节点
4. 订单详情页物流信息展示优化
5. 虚拟商品发货流程
6. 售后退货物流录入和跟踪
7. 自动确认收货机制完善

**暂不实现：**
- 真实快递API对接
- 到店自提完整流程
- 同城配送完整流程
- 智能分仓发货

### 1.2 验收标准
- 商家可对"待发货"实物订单填写运单号并发货
- 商家可对虚拟商品一键"无需物流"发货
- 客户端物流追踪页按时间轴显示完整物流节点
- 物流状态变更联动订单状态
- 签收后自动确认收货（商家和客户都有确认机制）
- 退货物流可录入退货运单号并在退款时跟踪

## 二、技术方案

### 2.1 数据库改动（最小化）

**orders表新增字段：**
- `logistics_company_id INTEGER` — 物流公司ID（已有logistics_info JSON，新增独立字段方便查询）

**logistics_tracks表增强：**
- 利用现有表，新增 `track_node TEXT` 字段区分节点类型：'ship'(发货)/'pick'(揽收)/'transit'(中转)/'deliver'(派送)/'sign'(签收)/'exception'(异常)

**新增返回物流表：**
- `return_logistics` — 退货物流记录
  - id, order_id, tracking_number, logistics_company_id, status, created_at, updated_at

### 2.2 页面改动

| 文件 | 改动内容 |
|------|---------|
| `merchant_order_detail_page.dart` | 添加"发货"按钮→弹出ShippingDialog |
| `merchant_order_management_page.dart` | 添加"一键发货"批量操作 |
| `logistics_tracking_page.dart` | 优化时间轴UI，添加进度条 |
| `order_detail_page.dart` | 优化物流入口，添加状态进度 |
| `after_sales_page.dart` | 添加退货物流录入和查看 |

### 2.3 新增文件

| 文件 | 用途 |
|------|------|
| `shipping_dialog.dart` | 发货对话框（实物/虚拟双模式） |
| `return_logistics_dialog.dart` | 退货物流录入对话框 |

### 2.4 状态机设计

实物商品状态流转：
```
pendingShip → (商家发货) → shipped → (录入揽收) → picked 
→ (运输更新) → transporting → (开始派送) → delivering 
→ (签收) → delivered → (自动确认) → completed
```

虚拟商品状态流转：
```
pendingShip → (无需物流发货) → completed
```