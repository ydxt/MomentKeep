import 'package:flutter/material.dart';

/// 日期范围选择工具类
class DatePickerUtils {
  /// 显示日期范围选择器
  static Future<DateTimeRange?> showDateRangePicker({
    required BuildContext context,
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
    );
  }

  /// 显示开始日期选择器
  static Future<DateTime?> showStartDatePicker({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF13ec5b),
              surface: Color(0xFF1a3525),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1a3525),
          ),
          child: child!,
        );
      },
    );
  }

  /// 显示结束日期选择器
  static Future<DateTime?> showEndDatePicker({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF13ec5b),
              surface: Color(0xFF1a3525),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1a3525),
          ),
          child: child!,
        );
      },
    );
  }
}

/// 日期范围筛选面板
class DateRangeFilterPanel extends StatefulWidget {
  /// 开始日期
  final DateTime? startDate;
  /// 结束日期
  final DateTime? endDate;
  /// 日期变更回调
  final Function(DateTime?, DateTime?) onDateChanged;

  const DateRangeFilterPanel({
    super.key,
    this.startDate,
    this.endDate,
    required this.onDateChanged,
  });

  @override
  State<DateRangeFilterPanel> createState() => _DateRangeFilterPanelState();
}

class _DateRangeFilterPanelState extends State<DateRangeFilterPanel> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  @override
  void didUpdateWidget(covariant DateRangeFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  /// 格式化日期
  String _formatDate(DateTime? date) {
    if (date == null) return '选择日期';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 选择开始日期
  Future<void> _selectStartDate() async {
    final picked = await DatePickerUtils.showStartDatePicker(
      context: context,
      initialDate: _startDate,
      lastDate: _endDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      widget.onDateChanged(_startDate, _endDate);
    }
  }

  /// 选择结束日期
  Future<void> _selectEndDate() async {
    final picked = await DatePickerUtils.showEndDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      widget.onDateChanged(_startDate, _endDate);
    }
  }

  /// 清除日期
  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    widget.onDateChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a3525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF326744).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '日期范围筛选',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_startDate != null || _endDate != null)
                TextButton(
                  onPressed: _clearDates,
                  child: const Text(
                    '清除',
                    style: TextStyle(color: Color(0xFF13ec5b)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112217),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF326744)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _startDate != null
                              ? const Color(0xFF13ec5b)
                              : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(_startDate),
                          style: TextStyle(
                            color: _startDate != null
                                ? Colors.white
                                : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '至',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112217),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF326744)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _endDate != null
                              ? const Color(0xFF13ec5b)
                              : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(_endDate),
                          style: TextStyle(
                            color: _endDate != null
                                ? Colors.white
                                : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 快捷选项
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickOption('今天', 0),
              _buildQuickOption('昨天', 1),
              _buildQuickOption('近7天', 7),
              _buildQuickOption('近30天', 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOption(String label, int days) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        setState(() {
          _startDate = now.subtract(Duration(days: days));
          _endDate = now;
        });
        widget.onDateChanged(_startDate, _endDate);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF112217),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_startDate != null &&
                    _endDate != null &&
                    _startDate == DateTime.now().subtract(Duration(days: days)))
                ? const Color(0xFF13ec5b)
                : const Color(0xFF326744),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: (_startDate != null &&
                    _endDate != null &&
                    _startDate == DateTime.now().subtract(Duration(days: days)))
                ? const Color(0xFF13ec5b)
                : Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
