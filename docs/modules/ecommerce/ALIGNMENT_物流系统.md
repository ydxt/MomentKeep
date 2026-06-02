# ALIGNMENT_物流系统.md

## 一、项目上下文分析

### 1.1 技术栈
- Flutter + Dart
- SQLite (3个独立数据库): moment_keep.db, moment_keep_products.db, moment_keep_users.db
- Riverpod 状态管理
- 物流相关表在 moment_keep_products.db 中 (ProductDatabaseService)

### 1.2 现有物流基础设施

**数据库表：**
- `logistics_companies` (物流公司): id, name, code, website, phone, is_active, sort_order, created_at, updated_at
- `logistics_tracks` (物流轨迹): id, order_id, logistics_company_id, tracking_number, status, description, location, track_time, created_at
- `orders.logistics_info` (订单物流信息JSON字段): 存储序列化的物流详情

**实体模型：**
- `LogisticsCompany` (star_exchange.dart) — 物流公司实体
- `LogisticsTrack` (star_exchange.dart) — 物流轨迹实体（DB用）
- `LogisticsInfo` (merchant_order_management_page.dart) — 物流信息聚合模型
- `LogisticsTrack` (merchant_order_management_page.dart) — 页面级物流轨迹模型（与DB模型重复定义）

**现有页面：**
- `logistics_page.dart` — 物流公司管理（商家端）
- `logistics_tracking_page.dart` — 物流跟踪查看（客户端/商家端通用）
- `merchant_order_detail_page.dart` — 商家订单详情（含物流信息显示，虚拟商品判断）
- `order_detail_page.dart` — 客户端订单详情
- `after_sales_page.dart` — 客户端售后页面（无退货物流）

**订单状态 (MerchantOrderStatus)：**
pendingPayment, pendingAccept, pendingShip, shipped, refunding, repair, completed, cancelled, refunded, rejected

## 二、需求理解

基于《网络商店客户购物&商家发货&全物流系统全套提示词文档》的需求：

### 2.1 核心需求
1. **实物商品物流履约**：用户下单→待付款→商家备货→发货（录快递单）→揽收→运输→派送→签收→自动确认收货
2. **虚拟商品无需物流**：付款后自动/手动发放权益，无快递单号、无物流轨迹
3. **售后物流闭环**：退货申请→用户寄回→退货运输→商家签收→退款完成
4. **双流程独立**：实物和虚拟商品订单状态机互不干扰

### 2.2 边界确认
本任务范围：**星星商店（Star Exchange）的物流系统**
- ✅ 包含：商家发货管理、物流跟踪查看、订单状态流转、虚拟商品处理、售后物流
- ❌ 不包含：真实快递API对接（使用模拟物流数据）、同城配送/到店自提的完整实现、自动发货卡密系统

## 三、差距分析

| 功能 | 需求 | 现状 | 差距 |
|------|------|------|------|
| 商家发货操作 | 选择物流公司+填写运单号+发货 | **缺失** | 需开发发货对话框 |
| 虚拟商品无物流发货 | 商家点击"无需物流"直接完成发货 | 有isElectronic判断但无操作入口 | 需添加发货按钮 |
| 物流状态时间线 | 完整节点+时间轴UI | logistics_tracking_page基础实现 | 需优化UI |
| 多商品部分发货 | 分开发货+部分完成状态 | **缺失** | 需添加 |
| 一键发货 | 批量发货 | **缺失** | 需添加 |
| 物流异常处理 | 揽收超时提醒、物流异常标记 | **缺失** | 需添加 |
| 退货物流跟踪 | 退货申请→寄回→商家签收 | **缺失（仅退款无物流）** | 需添加退货物流录入 |
| 自动确认收货 | 超时自动确认 | 已有基础逻辑 | 需验证完善 |
| 物流状态与订单状态联动 | 发货后订单状态变为shipped，签收后变为completed | 部分实现 | 需补充揽收/运输/派送节点 |
| 客户端订单详情物流入口 | 查看物流轨迹 | order_detail_page有查看按钮 | 需完善入口和UI |
| 进度条 | 配送进度条 | **缺失** | 需添加 |
| 商家发货超时提醒 | 超时未发货通知 | **缺失** | 需添加 |

## 四、疑问澄清

全部基于需求文档和现有项目架构自行决策，无需人工确认的问题：

1. **发货入口位置**：放在商家订单详情页（merchant_order_detail_page.dart）
2. **物流状态联动**：发货→shipped，揽收→shipped+track status picked，签收→completed
3. **虚拟商品发货**：付款成功→自动变为shipped→自动确认完成（无物流环节）
4. **快递单号来源**：商家手动输入（非API对接）
5. **物流轨迹数据**：手动录入+预置模拟节点（非真实API）