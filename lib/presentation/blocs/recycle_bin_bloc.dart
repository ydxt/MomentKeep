import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final itemsJson =
          jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('recycle_bin', itemsJson);
      // 保存保留天数设置
      await prefs.setInt('recycle_bin_retention_days', _retentionDays);
    } catch (e) {
      print('保存回收箱数据失败: $e');
    }
  }

  /// 从SharedPreferences加载回收箱数据
  Future<List<RecycleBinItem>> _loadRecycleBinFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString('recycle_bin');
      // 加载保留天数设置
      _retentionDays = prefs.getInt('recycle_bin_retention_days') ?? 30;
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList
            .map((itemJson) =>
                RecycleBinItem.fromJson(itemJson as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('加载回收箱数据失败: $e');
    }
    // 如果没有数据或加载失败，返回默认的空列表
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
