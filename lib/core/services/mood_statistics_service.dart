import 'package:moment_keep/domain/entities/diary.dart';

/// 心情统计服务
class MoodStatisticsService {
  static final MoodStatisticsService _instance = MoodStatisticsService._internal();
  factory MoodStatisticsService() => _instance;
  MoodStatisticsService._internal();

  /// 计算心情统计
  Map<String, dynamic> calculateMoodStats(List<Journal> diaries) {
    // 过滤有心情记录的日记
    final diariesWithMood = diaries.where((d) => d.mood != null).toList();
    
    if (diariesWithMood.isEmpty) {
      return {
        'hasData': false,
        'totalDiaries': diaries.length,
        'diariesWithMood': 0,
        'averageMood': 0.0,
        'moodDistribution': {},
        'recentMoods': [],
      };
    }

    // 计算平均心情
    final totalMood = diariesWithMood.fold<int>(0, (sum, d) => sum + (d.mood ?? 0));
    final averageMood = totalMood / diariesWithMood.length;

    // 计算心情分布
    final moodDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final diary in diariesWithMood) {
      if (diary.mood != null && moodDistribution.containsKey(diary.mood)) {
        moodDistribution[diary.mood] = moodDistribution[diary.mood]! + 1;
      }
    }

    // 获取最近的心情记录（按日期排序）
    final sortedDiaries = List<Journal>.from(diariesWithMood)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final recentMoods = sortedDiaries.take(30).map((d) => {
      'date': d.date.toIso8601String(),
      'mood': d.mood,
      'title': d.title,
    }).toList();

    return {
      'hasData': true,
      'totalDiaries': diaries.length,
      'diariesWithMood': diariesWithMood.length,
      'averageMood': averageMood,
      'moodDistribution': moodDistribution,
      'recentMoods': recentMoods,
      'moodTrend': _calculateMoodTrend(sortedDiaries),
    };
  }

  /// 计算心情趋势
  List<Map<String, dynamic>> _calculateMoodTrend(List<Journal> diaries) {
    if (diaries.isEmpty) return [];

    // 按日期分组计算平均心情
    final dailyMoods = <String, List<int>>{};
    
    for (final diary in diaries) {
      if (diary.mood != null) {
        final dateStr = diary.date.toIso8601String().split('T')[0];
        if (!dailyMoods.containsKey(dateStr)) {
          dailyMoods[dateStr] = [];
        }
        dailyMoods[dateStr]!.add(diary.mood!);
      }
    }

    final trend = dailyMoods.entries.map((entry) {
      final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return {
        'date': entry.key,
        'averageMood': avgMood,
        'count': entry.value.length,
      };
    }).toList();

    // 按日期排序
    trend.sort((a, b) => a['date'].compareTo(b['date']));
    return trend;
  }

  /// 获取心情emoji
  String getMoodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😢';
      case 2:
        return '😟';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  /// 获取心情标签
  String getMoodLabel(int mood) {
    switch (mood) {
      case 1:
        return '糟糕';
      case 2:
        return '不好';
      case 3:
        return '一般';
      case 4:
        return '不错';
      case 5:
        return '很棒';
      default:
        return '一般';
    }
  }

  /// 获取心情颜色
  int getMoodColor(int mood) {
    switch (mood) {
      case 1:
        return 0xFFE76F51;
      case 2:
        return 0xFFF4A261;
      case 3:
        return 0xFFE9C46A;
      case 4:
        return 0xFF2A9D8F;
      case 5:
        return 0xFF4CAF50;
      default:
        return 0xFFE9C46A;
    }
  }
}
