import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/services/database_service.dart';
import 'package:moment_keep/core/constants/storage_keys.dart';
import 'package:moment_keep/core/services/user_settings_service.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'dart:async';
import 'dart:convert';

/// 回收箱事件
abstract class RecycleBinEvent extends Equatable {
  const RecycleBinEvent();

  @override
  List<Object> get props => [];
}

/// 加载回收箱事件
class LoadRecycleBin extends RecycleBinEvent {}

/// 添加到回收箱事件
class AddToRecycleBin extends RecycleBinEvent {
  final RecycleBinItem item;

  const AddToRecycleBin(this.item);

  @override
  List<Object> get props => [item];
}

/// 从回收箱恢复事件
class RestoreFromRecycleBin extends RecycleBinEvent {
  final String itemId;

  const RestoreFromRecycleBin(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// 从回收箱删除事件
class DeleteFromRecycleBin extends RecycleBinEvent {
  final String itemId;

  const DeleteFromRecycleBin(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// 清空回收箱事件
class ClearRecycleBin extends RecycleBinEvent {}

/// 清理过期回收箱项目事件
class CleanupExpiredItems extends RecycleBinEvent {}

/// 设置回收箱保留时间事件
class SetRecycleBinRetentionDays extends RecycleBinEvent {
  final int days;

  const SetRecycleBinRetentionDays(this.days);

  @override
  List<Object> get props => [days];
}

/// 回收箱状态
abstract class RecycleBinState extends Equatable {
  const RecycleBinState();

  @override
  List<Object> get props => [];
}

/// 回收箱初始状态
class RecycleBinInitial extends RecycleBinState {}

/// 回收箱加载中状态
class RecycleBinLoading extends RecycleBinState {}

/// 回收箱加载完成状态
class RecycleBinLoaded extends RecycleBinState {
  final List<RecycleBinItem> items;
  final int retentionDays; // 回收箱项目保留天数

  const RecycleBinLoaded(this.items, {this.retentionDays = 30});

  @override
  List<Object> get props => [items, retentionDays];
}

/// 回收箱操作失败状态
class RecycleBinError extends RecycleBinState {
  final String message;

  const RecycleBinError(this.message);

  @override
  List<Object> get props => [message];
}

/// 回收箱BLoC
class RecycleBinBloc extends Bloc<RecycleBinEvent, RecycleBinState> {
  RecycleBinBloc() : super(RecycleBinInitial()) {
    on<LoadRecycleBin>(_onLoadRecycleBin);
    on<AddToRecycleBin>(_onAddToRecycleBin);
    on<RestoreFromRecycleBin>(_onRestoreFromRecycleBin);
    on<DeleteFromRecycleBin>(_onDeleteFromRecycleBin);
    on<ClearRecycleBin>(_onClearRecycleBin);
    on<CleanupExpiredItems>(_onCleanupExpiredItems);
    on<SetRecycleBinRetentionDays>(_onSetRecycleBinRetentionDays);

    // 初始化回收箱数据
    _items = [];
    _retentionDays = 30; // 默认保留30天
  }

  /// 回收箱数据
  late List<RecycleBinItem> _items;

  /// 回收箱项目保留天数
  late int _retentionDays;

  /// 保存回收箱数据到SharedPreferences
  Future<void> _saveRecycleBinToStorage() async {
    try {
      final dbService = DatabaseService();
      final userId = await dbService.getCurrentUserId() ?? 'default_user';
      await dbService.clearRecycleBin(userId);
      for (final item in _items) {
        final expiresAt = _retentionDays > 0
            ? item.deletedAt.add(Duration(days: _retentionDays)).toIso8601String()
            : null;
        await dbService.insertRecycleBinItem(
          userId,
          item.type,
          jsonEncode(item.toJson()),
          item.deletedAt.toIso8601String(),
          expiresAt: expiresAt,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.recycleBinRetentionDays, _retentionDays);
    } catch (e) {
      print('保存回收箱数据失败: $e');
    }
  }

  Future<List<RecycleBinItem>> _loadRecycleBinFromStorage() async {
    try {
      final dbService = DatabaseService();
      final userId = await dbService.getCurrentUserId() ?? 'default_user';
      final prefs = await SharedPreferences.getInstance();
      _retentionDays = prefs.getInt(StorageKeys.recycleBinRetentionDays) ?? 30;

      final dbItems = await dbService.getRecycleBinItems(userId);
      if (dbItems.isNotEmpty) {
        return dbItems.map((row) {
          final itemData = jsonDecode(row['item_data'] as String) as Map<String, dynamic>;
          return RecycleBinItem.fromJson(itemData);
        }).toList();
      }

      final itemsJson = prefs.getString(StorageKeys.recycleBin);
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        final items = itemsList
            .map((itemJson) =>
                RecycleBinItem.fromJson(itemJson as Map<String, dynamic>))
            .toList();
        for (final item in items) {
          final expiresAt = _retentionDays > 0
              ? item.deletedAt.add(Duration(days: _retentionDays)).toIso8601String()
              : null;
          await dbService.insertRecycleBinItem(
            userId,
            item.type,
            jsonEncode(item.toJson()),
            item.deletedAt.toIso8601String(),
            expiresAt: expiresAt,
          );
        }
        await prefs.remove(StorageKeys.recycleBin);
        return items;
      }
    } catch (e) {
      print('加载回收箱数据失败: $e');
    }
    return [];
  }

  /// 处理加载回收箱事件
  FutureOr<void> _onLoadRecycleBin(
      LoadRecycleBin event, Emitter<RecycleBinState> emit) async {
    emit(RecycleBinLoading());
    try {
      // 从SharedPreferences加载回收箱数据
      _items = await _loadRecycleBinFromStorage();
      // 清理过期项目
      _cleanupExpiredItems();
      emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
    } catch (e) {
      emit(RecycleBinError('加载回收箱失败'));
    }
  }

  /// 处理添加到回收箱事件
  FutureOr<void> _onAddToRecycleBin(
      AddToRecycleBin event, Emitter<RecycleBinState> emit) async {
    // 更新原始数据
    _items.add(event.item);

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 处理从回收箱恢复事件
  FutureOr<void> _onRestoreFromRecycleBin(
      RestoreFromRecycleBin event, Emitter<RecycleBinState> emit) async {
    // 更新原始数据
    _items.removeWhere((item) => item.id == event.itemId);

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 处理从回收箱删除事件
  FutureOr<void> _onDeleteFromRecycleBin(
      DeleteFromRecycleBin event, Emitter<RecycleBinState> emit) async {
    // 更新原始数据
    _items.removeWhere((item) => item.id == event.itemId);

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 处理清空回收箱事件
  FutureOr<void> _onClearRecycleBin(
      ClearRecycleBin event, Emitter<RecycleBinState> emit) async {
    // 清空原始数据
    _items.clear();

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 处理清理过期回收箱项目事件
  FutureOr<void> _onCleanupExpiredItems(
      CleanupExpiredItems event, Emitter<RecycleBinState> emit) async {
    // 清理过期项目
    _cleanupExpiredItems();

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 处理设置回收箱保留时间事件
  FutureOr<void> _onSetRecycleBinRetentionDays(
      SetRecycleBinRetentionDays event, Emitter<RecycleBinState> emit) async {
    // 更新原始数据
    _retentionDays = event.days;

    // 保存到SharedPreferences
    await _saveRecycleBinToStorage();

    // 清理过期项目
    _cleanupExpiredItems();

    // 直接使用更新后的原始数据创建新状态
    emit(RecycleBinLoaded(List.from(_items), retentionDays: _retentionDays));
  }

  /// 清理过期项目
  void _cleanupExpiredItems() {
    final expiredDate = DateTime.now().subtract(Duration(days: _retentionDays));
    _items.removeWhere((item) => item.deletedAt.isBefore(expiredDate));
  }
}
