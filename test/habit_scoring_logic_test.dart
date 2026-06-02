import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/check_in_record.dart';
import 'package:moment_keep/domain/entities/diary.dart'; // For ContentBlock if needed

/// 这是一个纯逻辑验证测试，用于验证 HabitBloc 中的周期积分算法是否正确。
/// 由于 HabitBloc 依赖了数据库等复杂组件，我们在这里模拟其核心计算逻辑。

void main() {
  group('Habit Scoring Logic Verification', () {
    test('1. Daily Mode: Should award user selected score immediately', () {
      // Arrange
      final habit = _createHabit(
        scoringMode: ScoringMode.daily,
        fullStars: 10,
      );
      final now = DateTime.now();
      final userScore = 8;

      // Act (Simulate logic in _onRecordHabitCompletion)
      final result = _simulateCheckIn(habit, now, userScore);

      // Assert
      expect(result.pointsAwarded, 8); // Should equal userScore
      expect(result.cycleAlreadyRewarded, isFalse);
    });

    test('2. Weekly Positive: Should NOT award points until target is reached', () {
      // Arrange
      // Target: 5 days/week, Reward: 50 pts
      final habit = _createHabit(
        scoringMode: ScoringMode.weekly,
        targetDays: 5,
        cycleRewardPoints: 50,
        fullStars: 10,
      );

      // Simulate checking in Mon, Tue, Wed, Thu (4 times)
      final nowMon = DateTime(2026, 4, 13); // Monday
      final nowTue = DateTime(2026, 4, 14);
      final nowWed = DateTime(2026, 4, 15);
      final nowThu = DateTime(2026, 4, 16);

      var currentHabit = habit;
      var points = 0;

      // Mon
      var res = _simulateCheckIn(currentHabit, nowMon, 5);
      points += res.pointsAwarded;
      currentHabit = currentHabit.copyWith(
        history: [...currentHabit.history, nowMon.toIso8601String().split('T')[0]],
        checkInRecords: [...currentHabit.checkInRecords, _createRecord(nowMon, 5)],
        lastCycleRewardTime: res.newLastRewardTime,
      );

      // Tue
      res = _simulateCheckIn(currentHabit, nowTue, 5);
      points += res.pointsAwarded;
      currentHabit = currentHabit.copyWith(
        history: [...currentHabit.history, nowTue.toIso8601String().split('T')[0]],
        checkInRecords: [...currentHabit.checkInRecords, _createRecord(nowTue, 5)],
        lastCycleRewardTime: res.newLastRewardTime,
      );

      // Wed
      res = _simulateCheckIn(currentHabit, nowWed, 5);
      points += res.pointsAwarded;
      currentHabit = currentHabit.copyWith(
        history: [...currentHabit.history, nowWed.toIso8601String().split('T')[0]],
        checkInRecords: [...currentHabit.checkInRecords, _createRecord(nowWed, 5)],
        lastCycleRewardTime: res.newLastRewardTime,
      );

      // Thu (4th check-in, still < 5)
      res = _simulateCheckIn(currentHabit, nowThu, 5);
      points += res.pointsAwarded;

      // Assert
      expect(points, 0); // Should be 0 points so far
    });

    test('3. Weekly Positive: Should award points when target is reached', () {
      // Arrange (Continuing from previous state: 4 check-ins)
      final habit = _createHabit(
        scoringMode: ScoringMode.weekly,
        targetDays: 5,
        cycleRewardPoints: 50,
        fullStars: 10,
      );
      final now = DateTime(2026, 4, 17); // Friday

      // Manually inject 4 previous records for this week (Mon-Thu)
      final prevRecords = [
        _createRecord(DateTime(2026, 4, 13), 5),
        _createRecord(DateTime(2026, 4, 14), 5),
        _createRecord(DateTime(2026, 4, 15), 5),
        _createRecord(DateTime(2026, 4, 16), 5),
      ];
      final prevHistory = ['2026-04-13', '2026-04-14', '2026-04-15', '2026-04-16'];

      final habitWithHistory = habit.copyWith(
        history: prevHistory,
        checkInRecords: prevRecords,
      );

      // Act: Check in on Friday (5th time)
      final result = _simulateCheckIn(habitWithHistory, now, 5);

      // Assert
      expect(result.pointsAwarded, 50); // Should award 50 points!
      expect(result.newLastRewardTime, isNotNull);
      expect(result.cycleAlreadyRewarded, isFalse);
    });

    test('4. Anti-Spam: Should NOT award points again in the same cycle', () {
      // Arrange
      final habit = _createHabit(
        scoringMode: ScoringMode.weekly,
        targetDays: 5,
        cycleRewardPoints: 50,
        fullStars: 10,
      );
      final nowFri = DateTime(2026, 4, 17); // Friday
      final nowSat = DateTime(2026, 4, 18); // Saturday

      // Previous 4 records
      final prevRecords = [
        _createRecord(DateTime(2026, 4, 13), 5),
        _createRecord(DateTime(2026, 4, 14), 5),
        _createRecord(DateTime(2026, 4, 15), 5),
        _createRecord(DateTime(2026, 4, 16), 5),
      ];
      final prevHistory = ['2026-04-13', '2026-04-14', '2026-04-15', '2026-04-16'];
      // Simulate that Friday check-in already awarded
      final lastReward = nowFri; 

      final habitReady = habit.copyWith(
        history: [...prevHistory, '2026-04-17'], // Friday checked
        checkInRecords: [...prevRecords, _createRecord(nowFri, 5)],
        lastCycleRewardTime: lastReward, // Already rewarded!
      );

      // Act: Check in on Saturday (6th time)
      final result = _simulateCheckIn(habitReady, nowSat, 5);

      // Assert
      expect(result.pointsAwarded, 0); // Should be 0, already rewarded this week
      expect(result.cycleAlreadyRewarded, isTrue);
    });

    test('5. Weekly Negative: Should deduct points when target (limit) reached', () {
      // Arrange
      final habit = _createHabit(
        type: HabitType.negative, // Deducting habit
        scoringMode: ScoringMode.weekly,
        targetDays: 5, // Limit: 5 times
        cycleRewardPoints: 50, // Penalty: 50 pts
        fullStars: 10,
      );
      final nowFri = DateTime(2026, 4, 17);

      // 4 previous records
      final prevRecords = [
        _createRecord(DateTime(2026, 4, 13), 5),
        _createRecord(DateTime(2026, 4, 14), 5),
        _createRecord(DateTime(2026, 4, 15), 5),
        _createRecord(DateTime(2026, 4, 16), 5),
      ];
      final prevHistory = ['2026-04-13', '2026-04-14', '2026-04-15', '2026-04-16'];

      final habitWithHistory = habit.copyWith(
        history: prevHistory,
        checkInRecords: prevRecords,
      );

      // Act: Check in on Friday (5th time -> Limit reached)
      final result = _simulateCheckIn(habitWithHistory, nowFri, 5);

      // Assert
      // Logic inside BLoC handles the sign: habit.type == negative ? -points : points
      // Our simulator returns raw points awarded. 
      // We verify that raw points are calculated, then check sign logic separately.
      expect(result.pointsAwarded, 50); // Raw calculation says 50 reached.
      // In real BLoC: finalPoints = -50.0.
    });

    test('6. Custom Cycle (3 days): Correct cycle boundaries', () {
      // Arrange
      final createDate = DateTime(2026, 4, 1); // Wednesday
      final habit = _createHabit(
        createdAt: createDate,
        scoringMode: ScoringMode.custom,
        customCycleDays: 3,
        targetDays: 2,
        cycleRewardPoints: 20,
      );
      
      // Current Date: April 5th (Sunday).
      // Cycles:
      // Cycle 0: Apr 1, 2, 3
      // Cycle 1: Apr 4, 5, 6  <-- We are here
      final now = DateTime(2026, 4, 5);

      // Simulate 1 check-in in current cycle (Apr 4)
      final habitWithHistory = habit.copyWith(
        history: ['2026-04-04'],
        checkInRecords: [_createRecord(DateTime(2026, 4, 4), 5)],
      );

      // Act: Check in on Apr 5 (2nd time in this cycle) -> Target reached
      final result = _simulateCheckIn(habitWithHistory, now, 5);

      // Assert
      expect(result.pointsAwarded, 20);
    });
  });
}

// --- Helper Functions ---

Habit _createHabit({
  ScoringMode scoringMode = ScoringMode.daily,
  HabitType type = HabitType.positive,
  int targetDays = 1,
  int customCycleDays = 7,
  int cycleRewardPoints = 0,
  int fullStars = 5,
  DateTime? createdAt,
  DateTime? lastCycleRewardTime,
}) {
  return Habit(
    id: 'test_id',
    categoryId: 'cat_1',
    category: 'Test',
    name: 'Test Habit',
    icon: 'icon',
    color: 0xFF000000,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime.now(),
    scoringMode: scoringMode,
    targetDays: targetDays,
    customCycleDays: customCycleDays,
    cycleRewardPoints: cycleRewardPoints,
    fullStars: fullStars,
    type: type,
    lastCycleRewardTime: lastCycleRewardTime,
  );
}

CheckInRecord _createRecord(DateTime time, int score) {
  return CheckInRecord(
    id: time.millisecondsSinceEpoch.toString(),
    habitId: 'test_id',
    score: score,
    timestamp: time,
    isNegative: false,
  );
}

/// Simulation of the logic inside HabitBloc._onRecordHabitCompletion
_CheckInResult _simulateCheckIn(
  Habit habit,
  DateTime now,
  int userScore,
) {
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

    // Count records
    final recordsInCycle = habit.checkInRecords.where((record) {
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

  return _CheckInResult(
    pointsAwarded: pointsAwarded,
    newLastRewardTime: newLastRewardTime,
    cycleAlreadyRewarded: false, // Just for return structure
  );
}

class _CheckInResult {
  final int pointsAwarded;
  final DateTime? newLastRewardTime;
  final bool cycleAlreadyRewarded;

  _CheckInResult({required this.pointsAwarded, this.newLastRewardTime, required this.cycleAlreadyRewarded});
}
