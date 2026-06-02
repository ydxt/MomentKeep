/// API 端点常量
/// 统一管理所有网络请求的端点，避免硬编码 URL
class ApiEndpoints {
  // ==================== 认证相关 ====================
  
  /// 登录
  static const String login = '/api/auth/login';
  
  /// 注册
  static const String register = '/api/auth/register';
  
  /// 登出
  static const String logout = '/api/auth/logout';
  
  /// 重置密码请求
  static const String requestPasswordReset = '/api/auth/reset-password';
  
  /// 重置密码确认
  static const String confirmPasswordReset = '/api/auth/reset-password/confirm';
  
  // ==================== 用户相关 ====================
  
  /// 获取用户信息
  static const String userProfile = '/api/user/profile';
  
  /// 更新用户信息
  static const String updateProfile = '/api/user/profile';
  
  /// 上传头像
  static const String uploadAvatar = '/api/user/avatar';
  
  // ==================== 待办事项 ====================
  
  /// 获取所有待办
  static const String todos = '/api/todos';
  
  /// 获取单个待办
  static String todoById(String id) => '/api/todos/$id';
  
  /// 创建待办
  static const String createTodo = '/api/todos';
  
  /// 更新待办
  static String updateTodo(String id) => '/api/todos/$id';
  
  /// 删除待办
  static String deleteTodo(String id) => '/api/todos/$id';
  
  // ==================== 习惯 ====================
  
  /// 获取所有习惯
  static const String habits = '/api/habits';
  
  /// 获取单个习惯
  static String habitById(String id) => '/api/habits/$id';
  
  /// 创建习惯
  static const String createHabit = '/api/habits';
  
  /// 更新习惯
  static String updateHabit(String id) => '/api/habits/$id';
  
  /// 删除习惯
  static String deleteHabit(String id) => '/api/habits/$id';
  
  /// 记录习惯完成
  static String recordHabitCompletion(String id) => '/api/habits/$id/complete';
  
  // ==================== 日记 ====================
  
  /// 获取所有日记
  static const String journals = '/api/journals';
  
  /// 获取单篇日记
  static String journalById(String id) => '/api/journals/$id';
  
  /// 创建日记
  static const String createJournal = '/api/journals';
  
  /// 更新日记
  static String updateJournal(String id) => '/api/journals/$id';
  
  /// 删除日记
  static String deleteJournal(String id) => '/api/journals/$id';
  
  // ==================== 分类 ====================
  
  /// 获取所有分类
  static const String categories = '/api/categories';
  
  /// 创建分类
  static const String createCategory = '/api/categories';
  
  /// 更新分类
  static String updateCategory(String id) => '/api/categories/$id';
  
  /// 删除分类
  static String deleteCategory(String id) => '/api/categories/$id';
  
  // ==================== 番茄钟 ====================
  
  /// 获取番茄钟记录
  static const String pomodoros = '/api/pomodoros';
  
  /// 创建番茄钟记录
  static const String createPomodoro = '/api/pomodoros';
  
  // ==================== 计划 ====================
  
  /// 获取所有计划
  static const String plans = '/api/plans';
  
  /// 创建计划
  static const String createPlan = '/api/plans';
  
  /// 更新计划
  static String updatePlan(String id) => '/api/plans/$id';
  
  /// 删除计划
  static String deletePlan(String id) => '/api/plans/$id';
  
  // ==================== 成就 ====================
  
  /// 获取所有成就
  static const String achievements = '/api/achievements';
  
  /// 更新成就进度
  static String updateAchievementProgress(String id) => '/api/achievements/$id/progress';
  
  // ==================== 同步相关 ====================
  
  /// 全量同步
  static const String fullSync = '/api/sync/full';
  
  /// 增量同步
  static const String incrementalSync = '/api/sync/incremental';
  
  /// 获取同步状态
  static const String syncStatus = '/api/sync/status';
  
  /// 推送离线操作
  static const String pushOfflineOperations = '/api/sync/offline';
  
  // ==================== 文件相关 ====================
  
  /// 上传文件
  static const String upload = '/api/upload';
  
  /// 删除文件
  static const String deleteFile = '/api/delete_file';
  
  /// 下载文件
  static String downloadFile(String fileId) => '/api/files/$fileId';
  
  // ==================== 积分相关 ====================
  
  /// 获取积分
  static const String points = '/api/points';
  
  /// 添加积分
  static const String addPoints = '/api/points/add';
  
  /// 扣除积分
  static const String deductPoints = '/api/points/deduct';
  
  /// 积分历史
  static const String pointsHistory = '/api/points/history';
  
  // ==================== 星星商店 ====================
  
  /// 获取商品列表
  static const String products = '/api/products';
  
  /// 获取商品详情
  static String productById(String id) => '/api/products/$id';
  
  /// 创建订单
  static const String createOrder = '/api/orders';
  
  /// 获取订单列表
  static const String orders = '/api/orders';
  
  /// 获取订单详情
  static String orderById(String id) => '/api/orders/$id';
  
  /// 申请退款
  static String requestRefund(String orderId) => '/api/orders/$orderId/refund';
  
  // ==================== 评价 ====================
  
  /// 提交评价
  static const String createReview = '/api/reviews';
  
  /// 获取评价
  static String reviewsByProductId(String productId) => '/api/products/$productId/reviews';
}
