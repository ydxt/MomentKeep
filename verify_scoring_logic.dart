/// 这是一个独立的 Dart 脚本，用于验证习惯计分逻辑的正确性。
/// 它不依赖 Flutter 框架，可以直接使用 `dart run verify_scoring_logic.dart` 运行。
/// 目的是在没有网络/环境依赖问题的情况下验证核心算法。

// --- 简化的模型 ---
enum ScoringMode { daily, weekly, custom }
enum HabitType { positive, negative }

class Habit {
  final String id;
  final ScoringMode scoringMode;
  final HabitType type;
  final int targetDays;
  final int customCycleDays;
  final int cycleRewardPoints;
  final int fullStars;
  final DateTime createdAt;
  final DateTime? lastCycleRewardTime;
  final List<String> history;
  final List<Record> records;

  Habit({
    required this.id,
    this.scoringMode = ScoringMode.daily,
    this.type = HabitType.positive,
    this.targetDays = 1,
    this.customCycleDays = 7,
    this.cycleRewardPoints = 0,
    this.fullStars = 5,
    required this.createdAt,
    this.lastCycleRewardTime,
    this.history = const [],
    this.records = const [],
  });
}

class Record {
  final DateTime timestamp;
  Record({required this.timestamp});
}

// --- 核心逻辑 (复刻自 habit_bloc.dart) ---
class ScoringResult {
  final int pointsAwarded;
  final DateTime? newLastRewardTime;
  final bool cycleAlreadyRewarded;
  ScoringResult(this.pointsAwarded, this.newLastRewardTime, this.cycleAlreadyRewarded);
}

ScoringResult calculatePoints(Habit habit, DateTime now, int userScore) {
  final today = DateTime(now.year, now.month, now.day);
  final todayStr = today.toIso8601String().split('T')[0];
  final isTodayChecked = habit.history.contains(todayStr);

  DateTime cycleStart;
  int pointsAwarded = 0;
  DateTime? newLastRewardTime = habit.lastCycleRewardTime;

  if (habit.scoringMode == ScoringMode.daily) {
    cycleStart = today;
    pointsAwarded = userScore;
  } else {
    if (habit.scoringMode == ScoringMode.weekly) {
      final weekday = now.weekday;
      cycleStart = today.subtract(Duration(days: weekday - 1));
    } else {
      final createDate = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      final daysSinceCreation = today.difference(createDate).inDays;
      if (daysSinceCreation < 0) {
        cycleStart = today;
      } else {
        final cycleIndex = daysSinceCreation ~/ habit.customCycleDays;
        cycleStart = createDate.add(Duration(days: cycleIndex * habit.customCycleDays));
      }
    }

    final recordsInCycle = habit.records.where((record) {
      final rDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      return !rDate.isBefore(cycleStart);
    }).length;

    final currentCycleCount = isTodayChecked ? recordsInCycle : recordsInCycle + 1;
    final bool targetReached = currentCycleCount >= habit.targetDays;
    
    bool cycleAlreadyRewarded = false;
    if (habit.lastCycleRewardTime != null) {
      final lastRewardDate = DateTime(habit.lastCycleRewardTime!.year, habit.lastCycleRewardTime!.month, habit.lastCycleRewardTime!.day);
      if (!lastRewardDate.isBefore(cycleStart)) {
        cycleAlreadyRewarded = true;
      }
    }

    if (targetReached && !cycleAlreadyRewarded) {
      pointsAwarded = habit.cycleRewardPoints;
      newLastRewardTime = now;
    } else {
      pointsAwarded = 0;
    }
  }
  return ScoringResult(pointsAwarded, newLastRewardTime, false);
}

// --- 测试用例 ---
void main() {
  print('=== 开始验证习惯计分逻辑 ===\n');
  bool allPassed = true;

  // Test 1: Daily Mode
  print('测试 1: 每天计分模式');
  var h1 = Habit(id: '1', scoringMode: ScoringMode.daily, fullStars: 10, createdAt: DateTime.now());
  var r1 = calculatePoints(h1, DateTime.now(), 8);
  if (r1.pointsAwarded == 8) {
    print('  ✅ 通过：打卡得分为用户选择的 8 分。\n');
  } else {
    print('  ❌ 失败：预期 8 分，实际 ${r1.pointsAwarded}\n');
    allPassed = false;
  }

  // Test 2: Weekly Positive (Not reached)
  print('测试 2: 按周计分（未达标）');
  // 目标 5 天，当前 4 次
  var now = DateTime(2026, 4, 16); // Thu
  var h2 = Habit(
    id: '2', 
    scoringMode: ScoringMode.weekly, 
    targetDays: 5, 
    cycleRewardPoints: 50,
    createdAt: DateTime(2026, 1, 1),
    records: [
      Record(timestamp: DateTime(2026, 4, 13)), // Mon
      Record(timestamp: DateTime(2026, 4, 14)), // Tue
      Record(timestamp: DateTime(2026, 4, 15)), // Wed
    ],
    history: ['2026-04-13', '2026-04-14', '2026-04-15'],
  );
  // Simulate 4th check-in (Thu)
  h2 = Habit(
    id: h2.id, scoringMode: h2.scoringMode, targetDays: h2.targetDays,
    cycleRewardPoints: h2.cycleRewardPoints, createdAt: h2.createdAt,
    records: [...h2.records, Record(timestamp: now)],
    history: [...h2.history, '2026-04-16'],
  );
  
  var r2 = calculatePoints(h2, now, 5);
  if (r2.pointsAwarded == 0) {
    print('  ✅ 通过：第 4 次打卡，未达标，得 0 分。\n');
  } else {
    print('  ❌ 失败：预期 0 分，实际 ${r2.pointsAwarded}\n');
    allPassed = false;
  }

  // Test 3: Weekly Positive (Reached)
  print('测试 3: 按周计分（达标）');
  // 继续 Test 2 的状态，再加 1 次 (Fri)
  var nowFri = DateTime(2026, 4, 17);
  var h3 = Habit(
    id: h2.id, scoringMode: h2.scoringMode, targetDays: h2.targetDays,
    cycleRewardPoints: h2.cycleRewardPoints, createdAt: h2.createdAt,
    records: [...h2.records, Record(timestamp: nowFri)],
    history: [...h2.history, '2026-04-17'],
  );
  var r3 = calculatePoints(h3, nowFri, 5);
  if (r3.pointsAwarded == 50) {
    print('  ✅ 通过：第 5 次打卡，达标，获得 50 分奖励。\n');
  } else {
    print('  ❌ 失败：预期 50 分，实际 ${r3.pointsAwarded}\n');
    allPassed = false;
  }

  // Test 4: Anti-Spam (Already rewarded)
  print('测试 4: 防刷机制（周期内重复打卡）');
  var nowSat = DateTime(2026, 4, 18);
  var h4 = Habit(
    id: h3.id, scoringMode: h3.scoringMode, targetDays: h3.targetDays,
    cycleRewardPoints: h3.cycleRewardPoints, createdAt: h3.createdAt,
    records: [...h3.records, Record(timestamp: nowSat)],
    history: [...h3.history, '2026-04-18'],
    lastCycleRewardTime: nowFri, // Simulate reward given on Friday
  );
  var r4 = calculatePoints(h4, nowSat, 5);
  if (r4.pointsAwarded == 0) {
    print('  ✅ 通过：本周期已发奖，第 6 次打卡不得分。\n');
  } else {
    print('  ❌ 失败：预期 0 分，实际 ${r4.pointsAwarded}\n');
    allPassed = false;
  }

  // Test 5: Negative Habit (Deduction)
  print('测试 5: 减分项逻辑');
  // 减分项逻辑主要在 BLoC 中处理正负号，这里验证计算器是否返回正值（BLoC 会将其转为负）
  var h5 = Habit(
    id: '5', scoringMode: ScoringMode.weekly, type: HabitType.negative,
    targetDays: 5, cycleRewardPoints: 50,
    createdAt: DateTime(2026, 1, 1),
    records: [
      Record(timestamp: DateTime(2026, 4, 13)),
      Record(timestamp: DateTime(2026, 4, 14)),
      Record(timestamp: DateTime(2026, 4, 15)),
      Record(timestamp: DateTime(2026, 4, 16)),
      Record(timestamp: DateTime(2026, 4, 17)),
    ],
    history: ['2026-04-13', '2026-04-14', '2026-04-15', '2026-04-16', '2026-04-17'],
  );
  var r5 = calculatePoints(h5, nowFri, 5);
  if (r5.pointsAwarded == 50) {
    print('  ✅ 通过：减分项达标，计算器返回 50（BLoC 将记为 -50 分）。\n');
  } else {
    print('  ❌ 失败：预期 50 分，实际 ${r5.pointsAwarded}\n');
    allPassed = false;
  }

  // Test 6: Custom Cycle (3 days)
  print('测试 6: 自定义周期（3天）');
  // CreateDate: Apr 1. Cycle 0: 1-3, Cycle 1: 4-6.
  // Now: Apr 5. Records in cycle 1: Apr 4 (1 count).
  // Target: 2.
  // Action: Check in Apr 5 (2nd count) -> Reached.
  var createDate = DateTime(2026, 4, 1);
  var nowCustom = DateTime(2026, 4, 5);
  var h6 = Habit(
    id: '6', scoringMode: ScoringMode.custom, customCycleDays: 3,
    targetDays: 2, cycleRewardPoints: 20,
    createdAt: createDate,
    records: [Record(timestamp: DateTime(2026, 4, 4))],
    history: ['2026-04-04'],
  );
  var r6 = calculatePoints(h6, nowCustom, 5);
  if (r6.pointsAwarded == 20) {
    print('  ✅ 通过：第 2 次打卡，达标 3 天周期，获得 20 分。\n');
  } else {
    print('  ❌ 失败：预期 20 分，实际 ${r6.pointsAwarded}\n');
    allPassed = false;
  }

  // Summary
  print('===========================');
  if (allPassed) {
    print('🎉 所有测试通过！逻辑正确。');
  } else {
    print('💥 部分测试失败，请检查代码。');
  }
  print('===========================');
}
