import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:path_provider/path_provider.dart';

/// 数据导出服务
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DatabaseService _databaseService = DatabaseService();

  /// 导出日记为 Markdown
  Future<String?> exportDiariesAsMarkdown({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // 构建查询
      String query = 'SELECT * FROM diaries WHERE 1=1';
      List<dynamic> args = [];

      if (startDate != null) {
        query += ' AND date >= ?';
        args.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        query += ' AND date <= ?';
        args.add(endDate.millisecondsSinceEpoch);
      }

      if (categoryId != null) {
        query += ' AND category_id = ?';
        args.add(categoryId);
      }

      query += ' ORDER BY date DESC';

      final diaryRecords = await db.rawQuery(query, args);

      if (diaryRecords.isEmpty) {
        return null;
      }

      // 构建 Markdown 内容
      final buffer = StringBuffer();
      buffer.writeln('# 日记导出');
      buffer.writeln();
      buffer.writeln('导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('导出范围: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : '开始'} 至 ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : '现在'}');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      for (final record in diaryRecords) {
        final date = DateTime.fromMillisecondsSinceEpoch(record['date'] as int);
        final title = record['title'] as String? ?? '无标题';
        final content = record['content'] as String? ?? '';
        final tags = record['tags'] as String? ?? '';

        buffer.writeln('## $title');
        buffer.writeln();
        buffer.writeln('**日期**: ${DateFormat('yyyy年MM月dd日').format(date)}');
        
        if (tags.isNotEmpty) {
          buffer.writeln('**标签**: $tags');
        }
        
        buffer.writeln();
        buffer.writeln(content);
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }

      // 保存到文件
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'diaries_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.md';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      debugPrint('Error exporting diaries: $e');
      return null;
    }
  }

  /// 导出习惯报告为 Markdown
  Future<String?> exportHabitReportAsMarkdown({
    DateTime? startDate,
    DateTime? endDate,
    String? habitId,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // 获取习惯列表
      String habitQuery = 'SELECT * FROM habits WHERE 1=1';
      List<dynamic> habitArgs = [];

      if (habitId != null) {
        habitQuery += ' AND id = ?';
        habitArgs.add(habitId);
      }

      final habitRecords = await db.rawQuery(habitQuery, habitArgs);

      if (habitRecords.isEmpty) {
        return null;
      }

      // 构建报告内容
      final buffer = StringBuffer();
      buffer.writeln('# 习惯打卡报告');
      buffer.writeln();
      buffer.writeln('生成时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      
      if (startDate != null || endDate != null) {
        buffer.writeln('统计范围: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : '开始'} 至 ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : '现在'}');
      }
      
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      // 总体统计
      int totalHabits = habitRecords.length;
      int totalCheckIns = 0;
      num bestStreak = 0;

      for (final habitRecord in habitRecords) {
        final habitId = habitRecord['id'] as String;
        
        // 获取打卡记录
        String recordQuery = 'SELECT * FROM habit_records WHERE habit_id = ?';
        List<dynamic> recordArgs = [habitId];

        if (startDate != null) {
          recordQuery += ' AND timestamp >= ?';
          recordArgs.add(startDate.millisecondsSinceEpoch);
        }

        if (endDate != null) {
          recordQuery += ' AND timestamp <= ?';
          recordArgs.add(endDate.millisecondsSinceEpoch);
        }

        recordQuery += ' ORDER BY timestamp DESC';

        final records = await db.rawQuery(recordQuery, recordArgs);
        totalCheckIns += (records.length as num).toInt();

        final habitName = habitRecord['name'] as String? ?? '未知习惯';
        final category = habitRecord['category'] as String? ?? '未分类';
        final habitBestStreak = (habitRecord['best_streak'] as num?)?.toInt() ?? 0;
        
        if (habitBestStreak > bestStreak) {
          bestStreak = habitBestStreak;
        }

        buffer.writeln('## $habitName');
        buffer.writeln();
        buffer.writeln('- **分类**: $category');
        buffer.writeln('- **打卡次数**: ${records.length}');
        buffer.writeln('- **最佳连续**: $habitBestStreak 天');
        buffer.writeln();

        // 打卡历史
        if (records.isNotEmpty) {
          buffer.writeln('### 最近打卡记录');
          buffer.writeln();
          buffer.writeln('| 日期 | 分数 | 备注 |');
          buffer.writeln('|------|------|------|');
          
          for (int i = 0; i < records.length && i < 30; i++) {
            final record = records[i];
            final timestamp = DateTime.fromMillisecondsSinceEpoch(record['timestamp'] as int);
            final score = record['score'] as int? ?? 0;
            final note = record['note'] as String? ?? '';
            
            buffer.writeln('| ${DateFormat('yyyy-MM-dd').format(timestamp)} | ${'⭐' * score} | $note |');
          }
          
          buffer.writeln();
        }

        buffer.writeln('---');
        buffer.writeln();
      }

      // 总体统计
      buffer.writeln('## 总体统计');
      buffer.writeln();
      buffer.writeln('- **习惯总数**: $totalHabits');
      buffer.writeln('- **打卡总次数**: $totalCheckIns');
      buffer.writeln('- **最佳连续打卡**: $bestStreak 天');
      buffer.writeln();

      // 保存到文件
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'habit_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.md';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      debugPrint('Error exporting habit report: $e');
      return null;
    }
  }

  /// 导出待办报告
  Future<String?> exportTodoReportAsMarkdown({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) async {
    try {
      final db = await _databaseService.database;
      
      String query = 'SELECT * FROM todos WHERE 1=1';
      List<dynamic> args = [];

      if (startDate != null) {
        query += ' AND created_at >= ?';
        args.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        query += ' AND created_at <= ?';
        args.add(endDate.millisecondsSinceEpoch);
      }

      if (categoryId != null) {
        query += ' AND category_id = ?';
        args.add(categoryId);
      }

      query += ' ORDER BY created_at DESC';

      final todoRecords = await db.rawQuery(query, args);

      if (todoRecords.isEmpty) {
        return null;
      }

      final buffer = StringBuffer();
      buffer.writeln('# 待办事项报告');
      buffer.writeln();
      buffer.writeln('生成时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      int totalTodos = todoRecords.length;
      int completedTodos = 0;

      for (final record in todoRecords) {
        final title = record['title'] as String? ?? '无标题';
        final isCompleted = (record['is_completed'] as num?) == 1;
        final priority = record['priority'] as String? ?? 'medium';
        final dueDate = record['due_date'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(record['due_date'] as int)
            : null;

        if (isCompleted) {
          completedTodos++;
        }

        buffer.writeln('## ${isCompleted ? '✅' : '⬜'} $title');
        buffer.writeln();
        buffer.writeln('- **优先级**: ${_getPriorityLabel(priority)}');
        buffer.writeln('- **状态**: ${isCompleted ? '已完成' : '未完成'}');
        
        if (dueDate != null) {
          buffer.writeln('- **截止日期**: ${DateFormat('yyyy-MM-dd').format(dueDate)}');
        }
        
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('## 总体统计');
      buffer.writeln();
      buffer.writeln('- **待办总数**: $totalTodos');
      buffer.writeln('- **已完成**: $completedTodos');
      buffer.writeln('- **未完成**: ${totalTodos - completedTodos}');
      buffer.writeln('- **完成率**: ${totalTodos > 0 ? (completedTodos / totalTodos * 100).toStringAsFixed(1) : 0}%');
      buffer.writeln();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'todo_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.md';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      debugPrint('Error exporting todo report: $e');
      return null;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return '🔴 高';
      case 'medium':
        return '🟡 中';
      case 'low':
        return '🟢 低';
      default:
        return '🟡 中';
    }
  }
}
