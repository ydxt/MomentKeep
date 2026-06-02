import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';
import 'package:moment_keep/services/database_service.dart';

/// 分类事件
abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object> get props => [];
}

/// 加载分类事件
class LoadCategories extends CategoryEvent {
  /// 分类类型
  final CategoryType? type;

  /// 构造函数
  const LoadCategories({this.type});

  @override
  List<Object> get props => [type ?? 'all'];
}

/// 添加分类事件
class AddCategory extends CategoryEvent {
  /// 分类
  final Category category;

  /// 构造函数
  const AddCategory(this.category);

  @override
  List<Object> get props => [category];
}

/// 更新分类事件
class UpdateCategory extends CategoryEvent {
  /// 分类
  final Category category;

  /// 构造函数
  const UpdateCategory(this.category);

  @override
  List<Object> get props => [category];
}

/// 删除分类事件
class DeleteCategory extends CategoryEvent {
  /// 分类ID
  final String id;

  /// 构造函数
  const DeleteCategory(this.id);

  @override
  List<Object> get props => [id];
}

/// 切换分类展开状态事件
class ToggleCategoryExpanded extends CategoryEvent {
  /// 分类ID
  final String id;

  /// 构造函数
  const ToggleCategoryExpanded(this.id);

  @override
  List<Object> get props => [id];
}

/// 更新分类顺序事件
class UpdateCategoryOrder extends CategoryEvent {
  /// 新的分类顺序列表
  final List<Category> categories;

  /// 构造函数
  const UpdateCategoryOrder(this.categories);

  @override
  List<Object> get props => [categories];
}

/// 分类状态
abstract class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object> get props => [];
}

/// 分类初始状态
class CategoryInitial extends CategoryState {}

/// 分类加载中状态
class CategoryLoading extends CategoryState {}

/// 分类加载成功状态
class CategoryLoaded extends CategoryState {
  /// 分类列表
  final List<Category> categories;

  /// 构造函数
  const CategoryLoaded(this.categories);

  @override
  List<Object> get props => [categories];
}

/// 分类加载失败状态
class CategoryError extends CategoryState {
  /// 错误信息
  final String message;

  /// 构造函数
  const CategoryError(this.message);

  @override
  List<Object> get props => [message];
}

/// 分类BLoC
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  /// 回收箱BLoC
  final RecycleBinBloc recycleBinBloc;

  late List<Category> _categories;

  CategoryType? _currentType;

  late SharedPreferences _prefs;

  final _dbService = DatabaseService();

  Future<void>? _initFuture;

  CategoryBloc(this.recycleBinBloc) : super(CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<ToggleCategoryExpanded>(_onToggleCategoryExpanded);
    on<UpdateCategoryOrder>(_onUpdateCategoryOrder);

    _initFuture = _initSharedPreferences();
  }

  /// 初始化SharedPreferences
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCategoriesFromStorage();
  }

  Future<void> _loadCategoriesFromStorage() async {
    try {
      final userId = await _dbService.getCurrentUserId() ?? 'default_user';
      final dbCategories = await _dbService.getCategories(userId);

      if (dbCategories.isNotEmpty) {
        _categories = dbCategories.map((row) {
          final data = <String, dynamic>{};
          if (row['data'] != null) {
            try {
              data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
            } catch (_) {}
          }
          return Category(
            id: row['id'].toString(),
            name: row['name'] as String,
            type: CategoryType.values.firstWhere(
              (e) => e.toString().split('.').last == row['type'],
              orElse: () => CategoryType.todo,
            ),
            icon: (row['icon'] as String?) ?? '',
            color: (row['color'] as int?) ?? 0,
            isExpanded: data['isExpanded'] as bool? ?? false,
            isQuestionBank: data['isQuestionBank'] as bool? ?? false,
          );
        }).toList();
      } else {
        final categoriesJson = _prefs.getString('categories');
        if (categoriesJson != null) {
          final categoriesList = jsonDecode(categoriesJson) as List<dynamic>;
          _categories = categoriesList
              .map((item) => Category.fromJson(item as Map<String, dynamic>))
              .toList();
          for (int i = 0; i < _categories.length; i++) {
            final cat = _categories[i];
            final dataJson = jsonEncode({
              'isExpanded': cat.isExpanded,
              'isQuestionBank': cat.isQuestionBank,
            });
            await _dbService.insertCategory(userId, {
              'name': cat.name,
              'icon': cat.icon,
              'color': cat.color,
              'type': cat.type.toString().split('.').last,
              'sort_order': i,
              'data': dataJson,
            });
          }
          final dbRows = await _dbService.getCategories(userId);
          _categories = dbRows.map((row) {
            final data = <String, dynamic>{};
            if (row['data'] != null) {
              try {
                data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
              } catch (_) {}
            }
            return Category(
              id: row['id'].toString(),
              name: row['name'] as String,
              type: CategoryType.values.firstWhere(
                (e) => e.toString().split('.').last == row['type'],
                orElse: () => CategoryType.todo,
              ),
              icon: (row['icon'] as String?) ?? '',
              color: (row['color'] as int?) ?? 0,
              isExpanded: data['isExpanded'] as bool? ?? false,
              isQuestionBank: data['isQuestionBank'] as bool? ?? false,
            );
          }).toList();
          await _prefs.remove('categories');
        } else {
          _categories = [
            Category(
              id: '1',
              name: '学习',
              type: CategoryType.habit,
              icon: 'book',
              color: 0xFF4CAF50,
              isExpanded: true,
            ),
            Category(
              id: '2',
              name: '运动',
              type: CategoryType.habit,
              icon: 'run',
              color: 0xFF2196F3,
              isExpanded: true,
            ),
            Category(
              id: '3',
              name: '工作',
              type: CategoryType.todo,
              icon: 'work',
              color: 0xFF9C27B0,
              isExpanded: true,
            ),
            Category(
              id: '4',
              name: '生活',
              type: CategoryType.todo,
              icon: 'home',
              color: 0xFFFF9800,
              isExpanded: true,
            ),
            Category(
              id: '5',
              name: '日记',
              type: CategoryType.journal,
              icon: 'note',
              color: 0xFFF44336,
              isExpanded: true,
            ),
            Category(
              id: '6',
              name: '错题本',
              type: CategoryType.journal,
              icon: 'error',
              color: 0xFFE91E63,
              isExpanded: true,
              isQuestionBank: true,
            ),
          ];
          _saveCategoriesToStorage();
        }
      }
    } catch (e) {
      print('加载分类数据失败: $e');
      _categories = [
        Category(
          id: '1',
          name: '学习',
          type: CategoryType.habit,
          icon: 'book',
          color: 0xFF4CAF50,
          isExpanded: true,
        ),
        Category(
          id: '2',
          name: '运动',
          type: CategoryType.habit,
          icon: 'run',
          color: 0xFF2196F3,
          isExpanded: true,
        ),
        Category(
          id: '3',
          name: '工作',
          type: CategoryType.todo,
          icon: 'work',
          color: 0xFF9C27B0,
          isExpanded: true,
        ),
        Category(
          id: '4',
          name: '生活',
          type: CategoryType.todo,
          icon: 'home',
          color: 0xFFFF9800,
          isExpanded: true,
        ),
        Category(
          id: '5',
          name: '日记',
          type: CategoryType.journal,
          icon: 'note',
          color: 0xFFF44336,
          isExpanded: true,
        ),
        Category(
          id: '6',
          name: '错题本',
          type: CategoryType.journal,
          icon: 'error',
          color: 0xFFE91E63,
          isExpanded: true,
          isQuestionBank: true,
        ),
      ];
    }
  }

  Future<void> _saveCategoriesToStorage() async {
    try {
      final userId = await _dbService.getCurrentUserId() ?? 'default_user';
      await _dbService.clearCategories(userId);
      for (int i = 0; i < _categories.length; i++) {
        final cat = _categories[i];
        final dataJson = jsonEncode({
          'isExpanded': cat.isExpanded,
          'isQuestionBank': cat.isQuestionBank,
        });
        await _dbService.insertCategory(userId, {
          'name': cat.name,
          'icon': cat.icon,
          'color': cat.color,
          'type': cat.type.toString().split('.').last,
          'sort_order': i,
          'data': dataJson,
        });
      }
      final dbRows = await _dbService.getCategories(userId);
      _categories = dbRows.map((row) {
        final data = <String, dynamic>{};
        if (row['data'] != null) {
          try {
            data.addAll(jsonDecode(row['data'] as String) as Map<String, dynamic>);
          } catch (_) {}
        }
        return Category(
          id: row['id'].toString(),
          name: row['name'] as String,
          type: CategoryType.values.firstWhere(
            (e) => e.toString().split('.').last == row['type'],
            orElse: () => CategoryType.todo,
          ),
          icon: (row['icon'] as String?) ?? '',
          color: (row['color'] as int?) ?? 0,
          isExpanded: data['isExpanded'] as bool? ?? false,
          isQuestionBank: data['isQuestionBank'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      print('保存分类数据失败: $e');
    }
  }

  /// 处理加载分类事件
  FutureOr<void> _onLoadCategories(
      LoadCategories event, Emitter<CategoryState> emit) async {
    emit(CategoryLoading());
    try {
      if (_initFuture != null) {
        await _initFuture;
      }
      _currentType = event.type;

      List<Category> categories = _categories;
      if (_currentType != null) {
        categories =
            _categories.where((cat) => cat.type == _currentType).toList();
      }
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError('加载分类失败'));
    }
  }

  /// 处理添加分类事件
  FutureOr<void> _onAddCategory(
      AddCategory event, Emitter<CategoryState> emit) async {
    _categories.add(event.category);

    await _saveCategoriesToStorage();

    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));
  }

  FutureOr<void> _onUpdateCategory(
      UpdateCategory event, Emitter<CategoryState> emit) async {
    final index = _categories.indexWhere((cat) => cat.id == event.category.id);
    if (index != -1) {
      _categories[index] = event.category;
    }

    await _saveCategoriesToStorage();

    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));
  }

  /// 处理删除分类事件
  FutureOr<void> _onDeleteCategory(
      DeleteCategory event, Emitter<CategoryState> emit) async {
    final categoryIndex = _categories.indexWhere((cat) => cat.id == event.id);
    if (categoryIndex != -1) {
      final deletedCategory = _categories[categoryIndex];

      final recycleBinItem = RecycleBinItem(
        id: deletedCategory.id,
        type: 'category',
        name: deletedCategory.name,
        data: deletedCategory.toJson(),
        deletedAt: DateTime.now(),
      );
      recycleBinBloc.add(AddToRecycleBin(recycleBinItem));

      _categories.removeAt(categoryIndex);

      await _saveCategoriesToStorage();

      List<Category> updatedCategories = _categories;
      if (_currentType != null) {
        updatedCategories =
            _categories.where((cat) => cat.type == _currentType).toList();
      }
      emit(CategoryLoaded(updatedCategories));
    }
  }

  FutureOr<void> _onToggleCategoryExpanded(
      ToggleCategoryExpanded event, Emitter<CategoryState> emit) async {
    final index = _categories.indexWhere((cat) => cat.id == event.id);
    if (index != -1) {
      _categories[index] = _categories[index]
          .copyWith(isExpanded: !_categories[index].isExpanded);
    }

    await _saveCategoriesToStorage();

    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));
  }

  FutureOr<void> _onUpdateCategoryOrder(
      UpdateCategoryOrder event, Emitter<CategoryState> emit) async {
    for (var newCategory in event.categories) {
      final index = _categories.indexWhere((cat) => cat.id == newCategory.id);
      if (index != -1) {
        _categories[index] = newCategory;
      }
    }

    final newOrder = event.categories.map((cat) => cat.id).toList();
    _categories.sort(
        (a, b) => newOrder.indexOf(a.id).compareTo(newOrder.indexOf(b.id)));

    await _saveCategoriesToStorage();

    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));
  }
}
