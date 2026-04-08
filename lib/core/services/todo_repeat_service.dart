import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/services/database_service.dart';

/// 重复任务服务
class TodoRepeatService {
  static final TodoRepeatService _instance = TodoRepeatService._internal();
  factory TodoRepeatService() => _instance;
  TodoRepeatService._internal();

  final DatabaseService _databaseService = DatabaseService();

  /// 完成任务时检查并生成下次重复任务
  Future<void> handleTaskCompletion(Todo completedTask) async {
    // 检查是否有重复配置
    if (completedTask.repeatType == RepeatType.none) {
      return;
    }

    // 计算下次重复日期
    final nextDate = _calculateNextRepeatDate(completedTask);

    if (nextDate == null) {
      return; // 重复已结束
    }

    // 创建新的重复任务
    await _createRepeatTask(completedTask, nextDate);
  }

  /// 计算下次重复日期
  DateTime? _calculateNextRepeatDate(Todo task) {
    final lastDate = task.lastRepeatDate ?? task.startDate ?? DateTime.now();

    // 检查是否超过重复结束日期
    if (task.repeatEndDate != null && lastDate.isAfter(task.repeatEndDate!)) {
      return null; // 重复已结束
    }

    DateTime? nextDate;

    switch (task.repeatType) {
      case RepeatType.daily:
        nextDate = _addDays(lastDate, task.repeatInterval);
        break;
      case RepeatType.weekly:
        nextDate = _addWeeks(lastDate, task.repeatInterval);
        break;
      case RepeatType.monthly:
        nextDate = _addMonths(lastDate, task.repeatInterval);
        break;
      case RepeatType.yearly:
        nextDate = _addYears(lastDate, task.repeatInterval);
        break;
      case RepeatType.custom:
      case RepeatType.none:
        return null;
    }

    // 再次检查是否超过结束日期
    if (task.repeatEndDate != null && nextDate.isAfter(task.repeatEndDate!)) {
      return null;
    }

    return nextDate;
  }

  /// 创建重复任务
  Future<void> _createRepeatTask(Todo originalTask, DateTime nextDate) async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    final newTaskId = DateTime.now().millisecondsSinceEpoch.toString();

    // 复制原任务，更新日期
    await db.insert('todos', {
      'id': newTaskId,
      'categoryId': originalTask.categoryId,
      'title': originalTask.title,
      'content': _contentBlocksToJson(originalTask.content),
      'is_completed': 0,
      'start_date': nextDate.millisecondsSinceEpoch,
      'date': nextDate.millisecondsSinceEpoch,
      'reminder_time': originalTask.reminderTime?.millisecondsSinceEpoch,
      'priority': originalTask.priority.name,
      'tags': originalTask.tags.join(','),
      'repeat_type': originalTask.repeatType.name,
      'repeat_interval': originalTask.repeatInterval,
      'repeat_end_date': originalTask.repeatEndDate?.millisecondsSinceEpoch,
      'last_repeat_date': now.millisecondsSinceEpoch,
      'is_location_reminder_enabled': originalTask.isLocationReminderEnabled ? 1 : 0,
      'latitude': originalTask.latitude,
      'longitude': originalTask.longitude,
      'radius': originalTask.radius,
      'location_name': originalTask.locationName,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    // 复制子任务（如果有）
    if (originalTask.subtasks.isNotEmpty) {
      for (final subtask in originalTask.subtasks) {
        await db.insert('subtasks', {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'todo_id': newTaskId,
          'title': subtask.title,
          'is_completed': 0, // 新任务子任务重置
          'order_index': subtask.orderIndex,
          'created_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        });
      }
    }

    // 更新原任务的 last_repeat_date
    await db.update(
      'todos',
      {'last_repeat_date': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [originalTask.id],
    );
  }

  /// 添加天数
  DateTime _addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  /// 添加周数
  DateTime _addWeeks(DateTime date, int weeks) {
    return date.add(Duration(days: weeks * 7));
  }

  /// 添加月数
  DateTime _addMonths(DateTime date, int months) {
    var year = date.year;
    var month = date.month + months;

    while (month > 12) {
      month -= 12;
      year++;
    }

    // 处理月末日期
    var day = date.day;
    final daysInMonth = _getDaysInMonth(year, month);
    if (day > daysInMonth) {
      day = daysInMonth;
    }

    return DateTime(year, month, day);
  }

  /// 添加年数
  DateTime _addYears(DateTime date, int years) {
    return DateTime(date.year + years, date.month, date.day);
  }

  /// 获取月份的天数
  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// 将ContentBlock列表转换为JSON字符串
  String _contentBlocksToJson(dynamic content) {
    try {
      if (content is List) {
        return content.map((block) {
          if (block.toJson != null) {
            return block.toJson();
          }
          return block;
        }).toList().toString();
      }
      return content?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }
}
