import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter/foundation.dart'; // 导入完整的foundation，用于kDebugMode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/services/database_service.dart';
import 'dart:async';
import 'dart:convert';

/// 智能日记事件
abstract class DiaryEvent extends Equatable {
  const DiaryEvent();

  @override
  List<Object> get props => [];
}

/// 加载智能日记事件
class LoadDiaryEntries extends DiaryEvent {}

/// 添加智能日记事件
class AddDiaryEntry extends DiaryEvent {
  final Journal entry;

  const AddDiaryEntry(this.entry);

  @override
  List<Object> get props => [entry];
}

/// 更新智能日记事件
class UpdateDiaryEntry extends DiaryEvent {
  final Journal entry;

  const UpdateDiaryEntry(this.entry);

  @override
  List<Object> get props => [entry];
}

/// 删除智能日记事件
class DeleteDiaryEntry extends DiaryEvent {
  final String entryId;

  const DeleteDiaryEntry(this.entryId);

  @override
  List<Object> get props => [entryId];
}

/// 更新日记顺序事件
class UpdateDiaryOrder extends DiaryEvent {
  final List<Journal> entries;

  const UpdateDiaryOrder(this.entries);

  @override
  List<Object> get props => [entries];
}

/// 智能日记状态
abstract class DiaryState extends Equatable {
  const DiaryState();

  @override
  List<Object> get props => [];
}

/// 智能日记初始状态
class DiaryInitial extends DiaryState {}

/// 智能日记加载中状态
class DiaryLoading extends DiaryState {}

/// 智能日记加载完成状态
class DiaryLoaded extends DiaryState {
  final List<Journal> entries;

  const DiaryLoaded(this.entries);

  @override
  List<Object> get props => [entries];
}

/// 智能日记操作失败状态
class DiaryError extends DiaryState {
  final String message;

  const DiaryError(this.message);

  @override
  List<Object> get props => [message];
}

/// 智能日记BLoC
class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  /// 回收箱BLoC
  final RecycleBinBloc recycleBinBloc;
  
  /// 数据库服务
  final DatabaseService _databaseService;

  DiaryBloc(this.recycleBinBloc) : 
        _databaseService = DatabaseService(),
        super(DiaryInitial()) {
    on<LoadDiaryEntries>(_onLoadDiaryEntries);
    on<AddDiaryEntry>(_onAddDiaryEntry);
    on<UpdateDiaryEntry>(_onUpdateDiaryEntry);
    on<DeleteDiaryEntry>(_onDeleteDiaryEntry);
    on<UpdateDiaryOrder>(_onUpdateDiaryOrder);

    // 初始化日记数据
    _entries = [];
  }

  /// 日记数据
  late List<Journal> _entries;

  /// 保存日记数据到本地存储（已废弃，改为直接使用数据库）
  @deprecated
  Future<void> _saveDiaryEntriesToStorage() async {
    // 不再使用SharedPreferences，所有数据直接通过数据库操作
    return;
  }

  /// 从存储加载日记数据
  Future<List<Journal>> _loadDiaryEntriesFromStorage() async {
    try {
      final journalsData = await _databaseService.getJournals();
      return journalsData.map((data) {
        // 确保content字段是字符串类型
        final content = data['content'] as String;
        // 检查content是否为空，避免解密失败导致的jsonDecode错误
        if (content.isEmpty) {
          return Journal.fromJson({
            ...data,
            'content': [],
          });
        }
        // 尝试解析JSON，处理可能的解析错误
        List<dynamic> contentData;
        try {
          contentData = jsonDecode(content) as List<dynamic>;
        } catch (e) {
          debugPrint('解析日记内容失败: $e');
          contentData = [];
        }
        return Journal.fromJson({
          ...data,
          'content': contentData,
        });
      }).toList();
    } catch (e) {
      debugPrint('从数据库加载日记失败: $e');
      return [];
    }
  }

  /// 处理加载智能日记事件
  FutureOr<void> _onLoadDiaryEntries(
      LoadDiaryEntries event, Emitter<DiaryState> emit) async {
    emit(DiaryLoading());
    try {
      // 从SharedPreferences加载日记数据
      _entries = await _loadDiaryEntriesFromStorage();
      // 添加详细日志
      debugPrint('Loaded ${_entries.length} journal entries from storage');
      emit(DiaryLoaded(List.from(_entries)));
    } catch (e) {
      debugPrint('Error loading diary entries: $e');
      // 如果加载失败，使用空列表初始化
      _entries = [];
      emit(DiaryLoaded(List.from(_entries)));
      // 可以选择显示错误信息，或者使用空列表继续
      // emit(DiaryError('加载智能日记失败: $e'));
    }
  }

  /// 处理添加智能日记事件
  FutureOr<void> _onAddDiaryEntry(
      AddDiaryEntry event, Emitter<DiaryState> emit) async {
    try {
      // 所有环境下都将日记插入到数据库
      final journalData = event.entry.toJson();
      // 将content转换为字符串，因为数据库中存储的是加密后的字符串
      journalData['content'] = jsonEncode(journalData['content']);
      // 插入日记，获取返回的自增ID
      await _databaseService.insertJournal(journalData);
      
      // 积分相关逻辑
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'default_user';
      
      // 获取日记完成的积分值
      final pointsPerDiary = prefs.getInt('points_per_diary') ?? 5;
      
      // 添加日记完成积分
      await _databaseService.updateUserPoints(
        userId,
        pointsPerDiary.toDouble(),
        description: '完成日记: ${event.entry.title}',
        transactionType: 'habit_completed',
        relatedId: event.entry.id,
      );
      
      // 重新从数据库加载所有日记，确保本地数据与数据库数据一致
      _entries = await _loadDiaryEntriesFromStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(DiaryLoaded(List.from(_entries)));
    } catch (e) {
      debugPrint('添加智能日记失败: $e');
      emit(DiaryError('添加智能日记失败: $e'));
    }
  }

  /// 处理更新智能日记事件
  FutureOr<void> _onUpdateDiaryEntry(
      UpdateDiaryEntry event, Emitter<DiaryState> emit) async {
    try {
      // 所有环境下都更新数据库
      final journalData = event.entry.toJson();
      // 将content转换为字符串，因为数据库中存储的是加密后的字符串
      journalData['content'] = jsonEncode(journalData['content']);
      // 将String类型的id转换为int类型
      final id = int.tryParse(event.entry.id) ?? 0;
      await _databaseService.updateJournal(id, journalData);
      
      // 重新从数据库加载所有日记，确保本地数据与数据库数据一致
      _entries = await _loadDiaryEntriesFromStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(DiaryLoaded(List.from(_entries)));
    } catch (e) {
      debugPrint('更新智能日记失败: $e');
      emit(DiaryError('更新智能日记失败: $e'));
    }
  }

  /// 处理删除智能日记事件
  FutureOr<void> _onDeleteDiaryEntry(
      DeleteDiaryEntry event, Emitter<DiaryState> emit) async {
    try {
      // 查找要删除的日记
      final entryIndex = 
          _entries.indexWhere((entry) => entry.id == event.entryId);
      if (entryIndex != -1) {
        final deletedEntry = _entries[entryIndex];

        // 所有环境下都从数据库删除日记
        // 将String类型的id转换为int类型
        final id = int.tryParse(deletedEntry.id) ?? 0;
        await _databaseService.deleteJournal(id);
        
        // 将删除的日记添加到回收箱
        final recycleBinItem = RecycleBinItem(
          id: deletedEntry.id,
          type: 'diary',
          name: deletedEntry.title.isEmpty ? '无标题日记' : deletedEntry.title,
          data: deletedEntry.toJson(),
          deletedAt: DateTime.now(),
        );
        recycleBinBloc.add(AddToRecycleBin(recycleBinItem));

        // 从本地列表中移除删除的日记，避免等待数据库操作
        _entries.removeAt(entryIndex);

        // 保存更新后的列表到本地存储
        await _saveDiaryEntriesToStorage();

        // 直接使用更新后的原始数据创建新状态
        emit(DiaryLoaded(List.from(_entries)));
      }
    } catch (e) {
      debugPrint('删除智能日记失败: $e');
      // 发生错误时，重新从数据库加载数据，确保数据一致性
      _entries = await _loadDiaryEntriesFromStorage();
      emit(DiaryLoaded(List.from(_entries)));
      // 可以选择显示错误信息，或者继续使用正确的数据
      // emit(DiaryError('删除智能日记失败: $e'));
    }
  }

  /// 处理更新日记顺序事件
  FutureOr<void> _onUpdateDiaryOrder(
      UpdateDiaryOrder event, Emitter<DiaryState> emit) async {
    try {
      // 更新原始数据
      _entries = event.entries;

      // 保存到SharedPreferences
      await _saveDiaryEntriesToStorage();

      // 直接使用更新后的原始数据创建新状态
      emit(DiaryLoaded(List.from(_entries)));
    } catch (e) {
      emit(DiaryError('更新日记顺序失败: $e'));
    }
  }
}
