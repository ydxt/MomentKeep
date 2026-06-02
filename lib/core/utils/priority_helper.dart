import 'package:flutter/material.dart';
import 'package:moment_keep/domain/entities/todo.dart';

class PriorityHelper {
  static Color getColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return Colors.red;
      case TodoPriority.medium:
        return Colors.orange;
      case TodoPriority.low:
        return Colors.green;
    }
  }

  static String getLabel(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return '高';
      case TodoPriority.medium:
        return '中';
      case TodoPriority.low:
        return '低';
    }
  }

  static IconData getIcon(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return Icons.arrow_upward;
      case TodoPriority.medium:
        return Icons.remove;
      case TodoPriority.low:
        return Icons.arrow_downward;
    }
  }

  static Widget buildBadge(TodoPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: PriorityHelper.getColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        PriorityHelper.getLabel(priority),
        style: TextStyle(
          color: PriorityHelper.getColor(priority),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
