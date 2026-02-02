import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/domain/entities/dashboard.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/presentation/blocs/dashboard_bloc.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';

void main() {
  // 初始化Flutter绑定
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('习惯完成率真实分类统计测试', () {
    late HabitBloc habitBloc;
    late RecycleBinBloc recycleBinBloc;
    late DashboardBloc dashboardBloc;
    late List<Habit> testHabits;

    setUp(() {
      // 初始化回收箱BLoC
      recycleBinBloc = RecycleBinBloc();
      
      // 初始化习惯BLoC
      habitBloc = HabitBloc(recycleBinBloc);
      
      // 创建测试习惯数据，包含不同分类
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      
      testHabits = [
        // 学习分类 - 已完成
        Habit(
          id: '1',
          name: '学习Flutter',
          category: '学习',
          categoryId: 'category_1',
          icon: '📚',
          color: 0xFF6200EE, // 紫色
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 7)),
          updatedAt: now,
          checkInRecords: [
            CheckInRecord(
              id: 'record_1',
              habitId: '1',
              score: 80,
              comment: [],
              timestamp: now,
            ),
          ],
        ),
        // 学习分类 - 未完成
        Habit(
          id: '2',
          name: '阅读书籍',
          category: '学习',
          categoryId: 'category_1',
          icon: '📖',
          color: 0xFF6200EE, // 紫色
          history: [],
          totalCompletions: 0,
          currentStreak: 0,
          bestStreak: 0,
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
          checkInRecords: [],
        ),
        // 运动分类 - 已完成
        Habit(
          id: '3',
          name: '跑步',
          category: '运动',
          categoryId: 'category_2',
          icon: '🏃',
          color: 0xFF03DAC6, // 青色
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now,
          checkInRecords: [
            CheckInRecord(
              id: 'record_3',
              habitId: '3',
              score: 90,
              comment: [],
              timestamp: now,
            ),
          ],
        ),
        // 生活分类 - 已完成
        Habit(
          id: '4',
          name: '喝水',
          category: '生活',
          categoryId: 'category_3',
          icon: '💧',
          color: 0xFFFF9800, // 橙色
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now,
          checkInRecords: [
            CheckInRecord(
              id: 'record_4',
              habitId: '4',
              score: 100,
              comment: [],
              timestamp: now,
            ),
          ],
        ),
        // 新的自定义分类 - 未完成
        Habit(
          id: '5',
          name: '冥想',
          category: '正念',
          categoryId: 'category_4',
          icon: '🧘',
          color: 0xFF4CAF50, // 绿色
          history: [],
          totalCompletions: 0,
          currentStreak: 0,
          bestStreak: 0,
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now,
          checkInRecords: [],
        ),
      ];
      
      // 加载测试数据到习惯BLoC
      habitBloc.add(LoadHabits());
      // 等待状态更新
      Future.delayed(const Duration(milliseconds: 100));
      
      // 添加测试习惯
      for (final habit in testHabits) {
        habitBloc.add(AddHabit(habit));
      }
      
      // 创建DashboardBloc并传入HabitBloc实例
      dashboardBloc = DashboardBloc(habitBloc);
    });

    tearDown(() {
      habitBloc.close();
      recycleBinBloc.close();
      dashboardBloc.close();
    });

    test('仪表板应使用真实的习惯分类计算完成率', () async {
      // 加载仪表板数据
      dashboardBloc.add(LoadDashboard());
      
      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 获取仪表板状态
      final state = dashboardBloc.state;
      
      // 验证状态类型
      expect(state, isA<DashboardLoaded>());
      
      final loadedState = state as DashboardLoaded;
      final dashboard = loadedState.dashboard;
      
      // 验证分类完成率不为空
      expect(dashboard.categoryCompletionRates.isNotEmpty, true);
      
      // 验证分类包含所有真实习惯分类
      final expectedCategories = {'学习', '运动', '生活', '正念'};
      expect(dashboard.categoryCompletionRates.keys.toSet(), equals(expectedCategories));
      
      // 验证分类完成率计算正确
      // 学习分类: 1个已完成，1个未完成 -> 50%完成率
      expect(dashboard.categoryCompletionRates['学习'], equals(0.5));
      
      // 运动分类: 1个已完成，0个未完成 -> 100%完成率
      expect(dashboard.categoryCompletionRates['运动'], equals(1.0));
      
      // 生活分类: 1个已完成，0个未完成 -> 100%完成率
      expect(dashboard.categoryCompletionRates['生活'], equals(1.0));
      
      // 正念分类: 0个已完成，1个未完成 -> 0%完成率
      expect(dashboard.categoryCompletionRates['正念'], equals(0.0));
      
      // 验证没有固定的假分类
      final fakeCategories = {'阅读'};
      for (final category in fakeCategories) {
        expect(dashboard.categoryCompletionRates.containsKey(category), false);
      }
    });

    test('空习惯列表应返回空的分类完成率', () async {
      // 创建一个新的习惯BLoC，不包含任何习惯
      final emptyHabitBloc = HabitBloc(recycleBinBloc);
      final emptyDashboardBloc = DashboardBloc(emptyHabitBloc);
      
      // 加载仪表板数据
      emptyDashboardBloc.add(LoadDashboard());
      
      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 获取仪表板状态
      final state = emptyDashboardBloc.state;
      
      // 验证状态类型
      expect(state, isA<DashboardLoaded>());
      
      final loadedState = state as DashboardLoaded;
      final dashboard = loadedState.dashboard;
      
      // 验证分类完成率为空
      expect(dashboard.categoryCompletionRates.isEmpty, true);
      
      // 关闭资源
      emptyHabitBloc.close();
      emptyDashboardBloc.close();
    });

    test('单个分类应正确计算完成率', () async {
      // 创建只包含一个分类的习惯列表
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      
      final singleCategoryHabits = [
        Habit(
          id: 'single_1',
          name: '俯卧撑',
          category: '运动',
          categoryId: 'category_2',
          icon: '🏋️',
          color: 0xFF03DAC6, // 青色
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
          checkInRecords: [],
        ),
        Habit(
          id: 'single_2',
          name: '仰卧起坐',
          category: '运动',
          categoryId: 'category_2',
          icon: '🧘',
          color: 0xFF03DAC6, // 青色
          history: [],
          totalCompletions: 0,
          currentStreak: 0,
          bestStreak: 0,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
          checkInRecords: [],
        ),
      ];
      
      // 创建新的习惯BLoC
      final singleCategoryHabitBloc = HabitBloc(recycleBinBloc);
      for (final habit in singleCategoryHabits) {
        singleCategoryHabitBloc.add(AddHabit(habit));
      }
      
      final singleCategoryDashboardBloc = DashboardBloc(singleCategoryHabitBloc);
      
      // 加载仪表板数据
      singleCategoryDashboardBloc.add(LoadDashboard());
      
      // 等待状态更新
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 获取仪表板状态
      final state = singleCategoryDashboardBloc.state;
      
      // 验证状态类型
      expect(state, isA<DashboardLoaded>());
      
      final loadedState = state as DashboardLoaded;
      final dashboard = loadedState.dashboard;
      
      // 验证只包含一个分类
      expect(dashboard.categoryCompletionRates.keys.length, equals(1));
      expect(dashboard.categoryCompletionRates.containsKey('运动'), true);
      
      // 验证完成率计算正确：1个已完成，1个未完成 -> 50%完成率
      expect(dashboard.categoryCompletionRates['运动'], equals(0.5));
      
      // 关闭资源
      singleCategoryHabitBloc.close();
      singleCategoryDashboardBloc.close();
    });
  });
}
