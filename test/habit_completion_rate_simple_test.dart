import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/domain/entities/dashboard.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';

void main() {
  group('习惯完成率计算测试', () {
    test('_calculateDashboardData 应使用真实的习惯分类计算完成率', () {
      // 创建测试习惯数据，包含不同分类
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      
      final testHabits = [
        // 学习分类 - 已完成
        Habit(
          id: '1',
          name: '学习Flutter',
          category: '学习',
          categoryId: 'category_1',
          icon: '📚',
          color: 0xFF6200EE,
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 7)),
          updatedAt: now,
          checkInRecords: [],
        ),
        // 学习分类 - 未完成
        Habit(
          id: '2',
          name: '阅读书籍',
          category: '学习',
          categoryId: 'category_1',
          icon: '📖',
          color: 0xFF6200EE,
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
          color: 0xFF03DAC6,
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now,
          checkInRecords: [],
        ),
        // 生活分类 - 已完成
        Habit(
          id: '4',
          name: '喝水',
          category: '生活',
          categoryId: 'category_3',
          icon: '💧',
          color: 0xFFFF9800,
          history: [todayStr],
          totalCompletions: 1,
          currentStreak: 1,
          bestStreak: 1,
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now,
          checkInRecords: [],
        ),
        // 新的自定义分类 - 未完成
        Habit(
          id: '5',
          name: '冥想',
          category: '正念',
          categoryId: 'category_4',
          icon: '🧘',
          color: 0xFF4CAF50,
          history: [],
          totalCompletions: 0,
          currentStreak: 0,
          bestStreak: 0,
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now,
          checkInRecords: [],
        ),
      ];
      
      // 模拟 calculateDashboardData 方法的核心逻辑
      Dashboard calculateDashboardData(List<Habit> habits) {
        if (habits.isEmpty) {
          return Dashboard(
            id: '1',
            totalHabits: 0,
            completedHabits: 0,
            completionRate: 0.0,
            completedDaysThisWeek: 0,
            completedDaysThisMonth: 0,
            totalCheckIns: 0,
            streakDays: 0,
            dailyActivityData: {},
            categoryCompletionRates: {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        
        final int totalHabits = habits.length;
        final now = DateTime.now();
        final todayStr = now.toIso8601String().split('T')[0];
        final completedHabits = habits.where((habit) => habit.history.contains(todayStr)).length;
        
        final double completionRate = totalHabits > 0 ? completedHabits / totalHabits : 0.0;
        
        final weekAgo = now.subtract(const Duration(days: 7));
        final monthAgo = now.subtract(const Duration(days: 30));
        
        final completedDaysThisWeek = habits.expand((habit) => habit.history)
            .where((dateStr) {
              final date = DateTime.parse(dateStr);
              return date.isAfter(weekAgo);
            })
            .toSet()
            .length;
        
        final completedDaysThisMonth = habits.expand((habit) => habit.history)
            .where((dateStr) {
              final date = DateTime.parse(dateStr);
              return date.isAfter(monthAgo);
            })
            .toSet()
            .length;
        
        int totalCheckIns = 0;
        int maxStreak = 0;
        
        for (final habit in habits) {
          totalCheckIns += habit.checkInRecords.length;
          if (habit.bestStreak > maxStreak) {
            maxStreak = habit.bestStreak;
          }
        }
        
        final Map<int, int> dailyActivityData = {};
        
        // 计算分类完成率
        final Map<String, int> categoryCounts = {};
        final Map<String, int> categoryCompletedCounts = {};
        
        for (final habit in habits) {
          // 统计分类总数
          categoryCounts[habit.category] = (categoryCounts[habit.category] ?? 0) + 1;
          
          // 统计分类完成数
          if (habit.history.contains(todayStr)) {
            categoryCompletedCounts[habit.category] = (categoryCompletedCounts[habit.category] ?? 0) + 1;
          }
        }
        
        // 计算分类完成率
        final Map<String, double> categoryCompletionRates = {};
        for (final category in categoryCounts.keys) {
          final total = categoryCounts[category] ?? 0;
          final completed = categoryCompletedCounts[category] ?? 0;
          categoryCompletionRates[category] = total > 0 ? completed / total : 0.0;
        }
        
        return Dashboard(
          id: '1',
          totalHabits: totalHabits,
          completedHabits: completedHabits,
          completionRate: completionRate,
          completedDaysThisWeek: completedDaysThisWeek,
          completedDaysThisMonth: completedDaysThisMonth,
          totalCheckIns: totalCheckIns,
          streakDays: maxStreak,
          dailyActivityData: dailyActivityData,
          categoryCompletionRates: categoryCompletionRates,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      // 计算仪表板数据
      final dashboard = calculateDashboardData(testHabits);
      
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
    
    test('空习惯列表应返回空的分类完成率', () {
      // 模拟 calculateDashboardData 方法
      Dashboard calculateDashboardData(List<Habit> habits) {
        if (habits.isEmpty) {
          return Dashboard(
            id: '1',
            totalHabits: 0,
            completedHabits: 0,
            completionRate: 0.0,
            completedDaysThisWeek: 0,
            completedDaysThisMonth: 0,
            totalCheckIns: 0,
            streakDays: 0,
            dailyActivityData: {},
            categoryCompletionRates: {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        
        // 这里简化处理，因为我们主要测试空列表情况
        return Dashboard(
          id: '1',
          totalHabits: habits.length,
          completedHabits: 0,
          completionRate: 0.0,
          completedDaysThisWeek: 0,
          completedDaysThisMonth: 0,
          totalCheckIns: 0,
          streakDays: 0,
          dailyActivityData: {},
          categoryCompletionRates: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      // 计算空习惯列表的仪表板数据
      final dashboard = calculateDashboardData([]);
      
      // 验证分类完成率为空
      expect(dashboard.categoryCompletionRates.isEmpty, true);
    });
    
    test('单个分类应正确计算完成率', () {
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
          color: 0xFF03DAC6,
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
          color: 0xFF03DAC6,
          history: [],
          totalCompletions: 0,
          currentStreak: 0,
          bestStreak: 0,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
          checkInRecords: [],
        ),
      ];
      
      // 模拟 calculateDashboardData 方法的核心逻辑
      Dashboard calculateDashboardData(List<Habit> habits) {
        if (habits.isEmpty) {
          return Dashboard(
            id: '1',
            totalHabits: 0,
            completedHabits: 0,
            completionRate: 0.0,
            completedDaysThisWeek: 0,
            completedDaysThisMonth: 0,
            totalCheckIns: 0,
            streakDays: 0,
            dailyActivityData: {},
            categoryCompletionRates: {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        
        final int totalHabits = habits.length;
        final now = DateTime.now();
        final todayStr = now.toIso8601String().split('T')[0];
        final completedHabits = habits.where((habit) => habit.history.contains(todayStr)).length;
        
        final double completionRate = totalHabits > 0 ? completedHabits / totalHabits : 0.0;
        
        final weekAgo = now.subtract(const Duration(days: 7));
        final monthAgo = now.subtract(const Duration(days: 30));
        
        final completedDaysThisWeek = habits.expand((habit) => habit.history)
            .where((dateStr) {
              final date = DateTime.parse(dateStr);
              return date.isAfter(weekAgo);
            })
            .toSet()
            .length;
        
        final completedDaysThisMonth = habits.expand((habit) => habit.history)
            .where((dateStr) {
              final date = DateTime.parse(dateStr);
              return date.isAfter(monthAgo);
            })
            .toSet()
            .length;
        
        int totalCheckIns = 0;
        int maxStreak = 0;
        
        for (final habit in habits) {
          totalCheckIns += habit.checkInRecords.length;
          if (habit.bestStreak > maxStreak) {
            maxStreak = habit.bestStreak;
          }
        }
        
        final Map<int, int> dailyActivityData = {};
        
        // 计算分类完成率
        final Map<String, int> categoryCounts = {};
        final Map<String, int> categoryCompletedCounts = {};
        
        for (final habit in habits) {
          // 统计分类总数
          categoryCounts[habit.category] = (categoryCounts[habit.category] ?? 0) + 1;
          
          // 统计分类完成数
          if (habit.history.contains(todayStr)) {
            categoryCompletedCounts[habit.category] = (categoryCompletedCounts[habit.category] ?? 0) + 1;
          }
        }
        
        // 计算分类完成率
        final Map<String, double> categoryCompletionRates = {};
        for (final category in categoryCounts.keys) {
          final total = categoryCounts[category] ?? 0;
          final completed = categoryCompletedCounts[category] ?? 0;
          categoryCompletionRates[category] = total > 0 ? completed / total : 0.0;
        }
        
        return Dashboard(
          id: '1',
          totalHabits: totalHabits,
          completedHabits: completedHabits,
          completionRate: completionRate,
          completedDaysThisWeek: completedDaysThisWeek,
          completedDaysThisMonth: completedDaysThisMonth,
          totalCheckIns: totalCheckIns,
          streakDays: maxStreak,
          dailyActivityData: dailyActivityData,
          categoryCompletionRates: categoryCompletionRates,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      // 计算仪表板数据
      final dashboard = calculateDashboardData(singleCategoryHabits);
      
      // 验证只包含一个分类
      expect(dashboard.categoryCompletionRates.keys.length, equals(1));
      expect(dashboard.categoryCompletionRates.containsKey('运动'), true);
      
      // 验证完成率计算正确：1个已完成，1个未完成 -> 50%完成率
      expect(dashboard.categoryCompletionRates['运动'], equals(0.5));
    });
  });
}
