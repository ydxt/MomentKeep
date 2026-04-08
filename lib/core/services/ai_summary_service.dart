import 'package:intl/intl.dart';
import 'package:moment_keep/services/database_service.dart';

/// AI 智能总结服务
/// 初期使用本地算法，后期可接入大模型 API
class AISummaryService {
  static final AISummaryService _instance = AISummaryService._internal();
  factory AISummaryService() => _instance;
  AISummaryService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // 情感关键词字典
  final Map<String, double> _sentimentWords = {
    // 积极情感
    '开心': 0.8, '快乐': 0.9, '高兴': 0.8, '幸福': 0.9, '满足': 0.7,
    '感恩': 0.8, '喜悦': 0.9, '愉快': 0.8, '欣喜': 0.9, '激动': 0.8,
    '满意': 0.7, '喜欢': 0.7, '爱': 0.9, '美好': 0.8, '成功': 0.8,
    '进步': 0.7, '成长': 0.7, '收获': 0.8, '希望': 0.6, '期待': 0.6,
    
    // 消极情感
    '难过': -0.7, '伤心': -0.8, '痛苦': -0.9, '悲伤': -0.9, '沮丧': -0.8,
    '失望': -0.7, '焦虑': -0.7, '烦躁': -0.6, '愤怒': -0.9, '生气': -0.8,
    '担心': -0.6, '害怕': -0.7, '孤独': -0.6, '疲惫': -0.5, '压力': -0.6,
    '失败': -0.8, '挫折': -0.6, '困惑': -0.5, '迷茫': -0.5, '无奈': -0.5,
    
    // 中性情感
    '平静': 0.2, '思考': 0.1, '学习': 0.3, '工作': 0.1, '生活': 0.2,
    '日常': 0.1, '记录': 0.1, '总结': 0.2, '反思': 0.3, '规划': 0.3,
  };

  /// 生成日记周总结
  Future<Map<String, dynamic>> generateDiaryWeeklySummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // 获取时间范围内的日记
      final diaries = await db.rawQuery('''
        SELECT * FROM diaries 
        WHERE date >= ? AND date <= ?
        ORDER BY date ASC
      ''', [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ]);

      if (diaries.isEmpty) {
        return {
          'success': false,
          'message': '该时间段内没有日记记录',
        };
      }

      // 统计分析
      int totalDiaries = diaries.length;
      int totalWords = 0;
      int totalImages = 0;
      int totalAudios = 0;
      double avgSentiment = 0;
      Map<String, int> tagStats = {};
      Map<String, int> categoryStats = {};
      List<String> topKeywords = [];

      for (final diary in diaries) {
        final content = diary['content'] as String? ?? '';
        final tags = diary['tags'] as String? ?? '';
        final categoryId = diary['category_id'] as String? ?? '';

        // 字数统计
        totalWords += content.length;

        // 媒体统计
        if (content.contains('image') || content.contains('Image')) {
          totalImages++;
        }
        if (content.contains('audio') || content.contains('Audio')) {
          totalAudios++;
        }

        // 情感分析
        double sentiment = _analyzeSentiment(content);
        avgSentiment += sentiment;

        // 标签统计
        if (tags.isNotEmpty) {
          final tagList = tags.split(',');
          for (final tag in tagList) {
            final trimmedTag = tag.trim();
            if (trimmedTag.isNotEmpty) {
              tagStats[trimmedTag] = (tagStats[trimmedTag] ?? 0) + 1;
            }
          }
        }

        // 分类统计
        if (categoryId.isNotEmpty) {
          categoryStats[categoryId] = (categoryStats[categoryId] ?? 0) + 1;
        }
      }

      avgSentiment = totalDiaries > 0 ? avgSentiment / totalDiaries : 0;

      // 提取关键词
      topKeywords = _extractKeywords(diaries.map((d) => d['content'] as String? ?? '').join(' '), topN: 10);

      // 生成总结文本
      final summary = _generateDiarySummaryText(
        totalDiaries: totalDiaries,
        totalWords: totalWords,
        totalImages: totalImages,
        totalAudios: totalAudios,
        avgSentiment: avgSentiment,
        topTags: tagStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
        topKeywords: topKeywords,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        'success': true,
        'summary': summary,
        'stats': {
          'totalDiaries': totalDiaries,
          'totalWords': totalWords,
          'totalImages': totalImages,
          'totalAudios': totalAudios,
          'avgSentiment': avgSentiment,
          'topTags': tagStats,
          'topKeywords': topKeywords,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': '生成总结失败: $e',
      };
    }
  }

  /// 生成习惯周总结
  Future<Map<String, dynamic>> generateHabitWeeklySummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // 获取所有习惯
      final habits = await db.rawQuery('SELECT * FROM habits');
      
      if (habits.isEmpty) {
        return {
          'success': false,
          'message': '没有习惯记录',
        };
      }

      List<Map<String, dynamic>> habitSummaries = [];
      int totalCheckIns = 0;
      int bestStreak = 0;
      Map<String, int> categoryStats = {};

      for (final habit in habits) {
        final habitId = habit['id'] as String;
        final habitName = habit['name'] as String;
        final category = habit['category'] as String? ?? '未分类';
        final habitBestStreak = habit['best_streak'] as int? ?? 0;

        // 获取时间范围内的打卡记录
        final records = await db.rawQuery('''
          SELECT * FROM habit_records 
          WHERE habit_id = ? AND timestamp >= ? AND timestamp <= ?
          ORDER BY timestamp ASC
        ''', [
          habitId,
          startDate.millisecondsSinceEpoch,
          endDate.millisecondsSinceEpoch,
        ]);

        int checkInCount = records.length;
        totalCheckIns += checkInCount;

        if (habitBestStreak > bestStreak) {
          bestStreak = habitBestStreak;
        }

        categoryStats[category] = (categoryStats[category] ?? 0) + 1;

        // 计算平均分数
        double avgScore = 0;
        if (records.isNotEmpty) {
          double totalScore = 0;
          for (final record in records) {
            totalScore += record['score'] as int? ?? 0;
          }
          avgScore = totalScore / records.length;
        }

        // 生成建议
        String suggestion = _generateHabitSuggestion(checkInCount, avgScore, habitBestStreak);

        habitSummaries.add({
          'name': habitName,
          'category': category,
          'checkInCount': checkInCount,
          'avgScore': avgScore,
          'bestStreak': habitBestStreak,
          'suggestion': suggestion,
        });
      }

      // 生成总结文本
      final summary = _generateHabitSummaryText(
        totalHabits: habits.length,
        totalCheckIns: totalCheckIns,
        bestStreak: bestStreak,
        habitSummaries: habitSummaries,
        categoryStats: categoryStats,
        startDate: startDate,
        endDate: endDate,
      );

      return {
        'success': true,
        'summary': summary,
        'stats': {
          'totalHabits': habits.length,
          'totalCheckIns': totalCheckIns,
          'bestStreak': bestStreak,
          'categoryStats': categoryStats,
          'habitSummaries': habitSummaries,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': '生成总结失败: $e',
      };
    }
  }

  /// 情感分析（简单版本）
  double _analyzeSentiment(String text) {
    double totalSentiment = 0;
    int wordCount = 0;

    for (final entry in _sentimentWords.entries) {
      if (text.contains(entry.key)) {
        totalSentiment += entry.value;
        wordCount++;
      }
    }

    return wordCount > 0 ? totalSentiment / wordCount : 0;
  }

  /// 提取关键词
  List<String> _extractKeywords(String text, {int topN = 10}) {
    // 简单的词频统计
    Map<String, int> wordFreq = {};
    
    // 分词（简单实现：按常见词汇切分）
    final words = text.split(RegExp(r'[，。！？、；：""''（）【】《》\s]+'));
    
    for (final word in words) {
      final trimmedWord = word.trim();
      // 过滤掉单字和常见停用词
      if (trimmedWord.length > 1 && 
          !['的是', '了', '和', '与', '或', '但', '而', '在', '有', '这', '那', '什么', '怎么', '为什么'].contains(trimmedWord)) {
        wordFreq[trimmedWord] = (wordFreq[trimmedWord] ?? 0) + 1;
      }
    }

    // 按频率排序
    final sortedWords = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords.take(topN).map((e) => e.key).toList();
  }

  /// 生成日记总结文本
  String _generateDiarySummaryText({
    required int totalDiaries,
    required int totalWords,
    required int totalImages,
    required int totalAudios,
    required double avgSentiment,
    required List<MapEntry<String, int>> topTags,
    required List<String> topKeywords,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('📔 日记周总结');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('📅 时间范围: ${DateFormat('MM月dd日').format(startDate)} - ${DateFormat('MM月dd日').format(endDate)}');
    buffer.writeln();
    
    buffer.writeln('📊 统计数据:');
    buffer.writeln('  • 日记总数: $totalDiaries 篇');
    buffer.writeln('  • 总字数: $totalWords 字');
    buffer.writeln('  • 图片数量: $totalImages 张');
    buffer.writeln('  • 音频数量: $totalAudios 个');
    buffer.writeln();

    // 情感分析
    String sentimentLabel;
    String sentimentEmoji;
    if (avgSentiment > 0.3) {
      sentimentLabel = '积极向上';
      sentimentEmoji = '😊';
    } else if (avgSentiment > 0.1) {
      sentimentLabel = '平稳向好';
      sentimentEmoji = '🙂';
    } else if (avgSentiment > -0.1) {
      sentimentLabel = '平淡如水';
      sentimentEmoji = '😐';
    } else if (avgSentiment > -0.3) {
      sentimentLabel = '略显低沉';
      sentimentEmoji = '😕';
    } else {
      sentimentLabel = '需要关注';
      sentimentEmoji = '😢';
    }

    buffer.writeln('💭 情感分析:');
    buffer.writeln('  $sentimentEmoji 整体情感: $sentimentLabel (${avgSentiment.toStringAsFixed(2)})');
    buffer.writeln();

    // 热门标签
    if (topTags.isNotEmpty) {
      buffer.writeln('🏷️ 热门标签:');
      for (int i = 0; i < topTags.length && i < 5; i++) {
        buffer.writeln('  ${i + 1}. ${topTags[i].key} (${topTags[i].value}次)');
      }
      buffer.writeln();
    }

    // 关键词
    if (topKeywords.isNotEmpty) {
      buffer.writeln('🔑 高频关键词:');
      buffer.writeln('  ${topKeywords.take(5).join('、')}');
      buffer.writeln();
    }

    // 建议
    buffer.writeln('💡 智能建议:');
    if (totalDiaries < 3) {
      buffer.writeln('  📝 本周日记较少，建议每天花5分钟记录生活点滴');
    } else if (totalDiaries >= 7) {
      buffer.writeln('  ✨ 非常棒！保持了良好的记录习惯');
    }
    
    if (totalImages == 0 && totalAudios == 0) {
      buffer.writeln('  📷 可以尝试添加图片或音频，让日记更生动');
    }

    if (avgSentiment < -0.2) {
      buffer.writeln('  💚 注意情绪调节，保持积极心态，必要时寻求支持');
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('继续坚持，每一天都值得记录！✨');

    return buffer.toString();
  }

  /// 生成习惯总结文本
  String _generateHabitSummaryText({
    required int totalHabits,
    required int totalCheckIns,
    required int bestStreak,
    required List<Map<String, dynamic>> habitSummaries,
    required Map<String, int> categoryStats,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('🎯 习惯打卡周总结');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('📅 时间范围: ${DateFormat('MM月dd日').format(startDate)} - ${DateFormat('MM月dd日').format(endDate)}');
    buffer.writeln();
    
    buffer.writeln('📊 总体统计:');
    buffer.writeln('  • 习惯总数: $totalHabits 个');
    buffer.writeln('  • 打卡总次数: $totalCheckIns 次');
    buffer.writeln('  • 最佳连续: $bestStreak 天');
    buffer.writeln();

    // 分类统计
    buffer.writeln('📂 分类分布:');
    categoryStats.forEach((category, count) {
      buffer.writeln('  • $category: $count 个习惯');
    });
    buffer.writeln();

    // 习惯详情
    buffer.writeln('📋 习惯详情:');
    buffer.writeln();
    
    for (final habit in habitSummaries) {
      buffer.writeln('🔹 ${habit['name']}');
      buffer.writeln('   分类: ${habit['category']}');
      buffer.writeln('   本周打卡: ${habit['checkInCount']} 次');
      buffer.writeln('   平均分数: ${(habit['avgScore'] as double).toStringAsFixed(1)}/5.0');
      buffer.writeln('   最佳连续: ${habit['bestStreak']} 天');
      buffer.writeln('   💡 ${habit['suggestion']}');
      buffer.writeln();
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('坚持就是胜利，让优秀成为一种习惯！💪');

    return buffer.toString();
  }

  /// 生成习惯建议
  String _generateHabitSuggestion(int checkInCount, double avgScore, int bestStreak) {
    if (checkInCount == 0) {
      return '本周未打卡，建议重新规划并坚持执行';
    } else if (checkInCount <= 2) {
      return '打卡频率较低，建议设定更具体的执行时间';
    } else if (avgScore < 3.0) {
      return '完成质量有待提高，建议降低难度或增加提醒';
    } else if (avgScore >= 4.0 && checkInCount >= 5) {
      return '表现优秀！可以考虑增加新习惯或提高现有习惯难度';
    } else if (bestStreak >= 7) {
      return '连续打卡表现良好，继续保持！';
    } else {
      return '表现不错，继续加油！';
    }
  }

  /// 生成待办周总结
  Future<Map<String, dynamic>> generateTodoWeeklySummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _databaseService.database;
      
      final todos = await db.rawQuery('''
        SELECT * FROM todos 
        WHERE created_at >= ? AND created_at <= ?
        ORDER BY created_at ASC
      ''', [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ]);

      if (todos.isEmpty) {
        return {
          'success': false,
          'message': '该时间段内没有待办记录',
        };
      }

      int totalTodos = todos.length;
      int completedTodos = todos.where((t) => t['is_completed'] as int == 1).length;
      int highPriorityTodos = todos.where((t) => t['priority'] as String == 'high').length;
      int overdueTodos = todos.where((t) {
        final dueDate = t['due_date'] as int?;
        final isCompleted = t['is_completed'] as int == 0;
        return dueDate != null && dueDate < DateTime.now().millisecondsSinceEpoch && isCompleted;
      }).length;

      double completionRate = totalTodos > 0 ? completedTodos / totalTodos : 0;

      // 生成总结文本
      final buffer = StringBuffer();
      buffer.writeln('✅ 待办事项周总结');
      buffer.writeln('━━━━━━━━━━━━━━━━━━');
      buffer.writeln();
      buffer.writeln('📅 时间范围: ${DateFormat('MM月dd日').format(startDate)} - ${DateFormat('MM月dd日').format(endDate)}');
      buffer.writeln();
      
      buffer.writeln('📊 统计数据:');
      buffer.writeln('  • 待办总数: $totalTodos');
      buffer.writeln('  • 已完成: $completedTodos');
      buffer.writeln('  • 未完成: ${totalTodos - completedTodos}');
      buffer.writeln('  • 完成率: ${(completionRate * 100).toStringAsFixed(1)}%');
      buffer.writeln('  • 高优先级: $highPriorityTodos');
      buffer.writeln('  • 已逾期: $overdueTodos');
      buffer.writeln();

      buffer.writeln('💡 智能建议:');
      if (completionRate < 0.5) {
        buffer.writeln('  ⚠️ 完成率较低，建议合理分配任务量，避免过度承诺');
      } else if (completionRate >= 0.8) {
        buffer.writeln('  ✨ 完成率很高，继续保持！');
      }
      
      if (overdueTodos > 3) {
        buffer.writeln('  ⏰ 逾期任务较多，建议及时清理或重新规划');
      }
      
      if (highPriorityTodos > totalTodos * 0.5) {
        buffer.writeln('  🔴 高优先级任务占比过大，建议重新评估优先级');
      }

      buffer.writeln();
      buffer.writeln('━━━━━━━━━━━━━━━━━━');
      buffer.writeln('高效完成，让生活更有序！🎯');

      return {
        'success': true,
        'summary': buffer.toString(),
        'stats': {
          'totalTodos': totalTodos,
          'completedTodos': completedTodos,
          'completionRate': completionRate,
          'highPriorityTodos': highPriorityTodos,
          'overdueTodos': overdueTodos,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': '生成总结失败: $e',
      };
    }
  }
}
