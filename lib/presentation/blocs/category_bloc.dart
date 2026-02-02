import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moment_keep/domain/entities/category.dart';
import 'package:moment_keep/domain/entities/recycle_bin.dart';
import 'package:moment_keep/presentation/blocs/recycle_bin_bloc.dart';

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

  /// 分类数据
  late List<Category> _categories;

  /// 当前请求的分类类型
  CategoryType? _currentType;

  /// SharedPreferences实例
  late SharedPreferences _prefs;

  /// 构造函数
  CategoryBloc(this.recycleBinBloc) : super(CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<ToggleCategoryExpanded>(_onToggleCategoryExpanded);
    on<UpdateCategoryOrder>(_onUpdateCategoryOrder);

    // 初始化SharedPreferences并加载分类数据
    _initSharedPreferences();
  }

  /// 初始化SharedPreferences
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    // 从存储加载分类数据
    _loadCategoriesFromStorage();
  }

  /// 从存储加载分类数据
  Future<void> _loadCategoriesFromStorage() async {
    try {
      final categoriesJson = _prefs.getString('categories');
      if (categoriesJson != null) {
        final categoriesList = jsonDecode(categoriesJson) as List<dynamic>;
        _categories = categoriesList
            .map((item) => Category.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // 如果没有存储的数据，使用默认分类
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
        // 保存默认分类到存储
        _saveCategoriesToStorage();
      }
    } catch (e) {
      print('加载分类数据失败: $e');
      // 加载失败时使用默认分类
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

  /// 保存分类数据到存储
  Future<void> _saveCategoriesToStorage() async {
    try {
      final categoriesJson =
          jsonEncode(_categories.map((category) => category.toJson()).toList());
      await _prefs.setString('categories', categoriesJson);
    } catch (e) {
      print('保存分类数据失败: $e');
    }
  }

  /// 处理加载分类事件
  FutureOr<void> _onLoadCategories(
      LoadCategories event, Emitter<CategoryState> emit) async {
    emit(CategoryLoading());
    try {
      // 模拟异步加载
      await Future.delayed(const Duration(milliseconds: 500));

      // 保存当前请求的类型
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
      AddCategory event, Emitter<CategoryState> emit) {
    // 更新原始数据
    _categories.add(event.category);

    // 使用保存的类型过滤分类列表
    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));

    // 保存到存储
    _saveCategoriesToStorage();
  }

  /// 处理更新分类事件
  FutureOr<void> _onUpdateCategory(
      UpdateCategory event, Emitter<CategoryState> emit) {
    // 更新原始数据
    final index = _categories.indexWhere((cat) => cat.id == event.category.id);
    if (index != -1) {
      _categories[index] = event.category;
    }

    // 使用保存的类型过滤分类列表
    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));

    // 保存到存储
    _saveCategoriesToStorage();
  }

  /// 处理删除分类事件
  FutureOr<void> _onDeleteCategory(
      DeleteCategory event, Emitter<CategoryState> emit) {
    // 查找要删除的分类
    final categoryIndex = _categories.indexWhere((cat) => cat.id == event.id);
    if (categoryIndex != -1) {
      final deletedCategory = _categories[categoryIndex];

      // 将删除的分类添加到回收箱
      final recycleBinItem = RecycleBinItem(
        id: deletedCategory.id,
        type: 'category',
        name: deletedCategory.name,
        data: deletedCategory.toJson(),
        deletedAt: DateTime.now(),
      );
      recycleBinBloc.add(AddToRecycleBin(recycleBinItem));

      // 更新原始数据
      _categories.removeAt(categoryIndex);

      // 使用保存的类型过滤分类列表
      List<Category> updatedCategories = _categories;
      if (_currentType != null) {
        updatedCategories =
            _categories.where((cat) => cat.type == _currentType).toList();
      }
      emit(CategoryLoaded(updatedCategories));

      // 保存到存储
      _saveCategoriesToStorage();
    }
  }

  /// 处理切换分类展开状态事件
  FutureOr<void> _onToggleCategoryExpanded(
      ToggleCategoryExpanded event, Emitter<CategoryState> emit) {
    // 更新原始数据
    final index = _categories.indexWhere((cat) => cat.id == event.id);
    if (index != -1) {
      _categories[index] = _categories[index]
          .copyWith(isExpanded: !_categories[index].isExpanded);
    }

    // 使用保存的类型过滤分类列表
    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));

    // 保存到存储
    _saveCategoriesToStorage();
  }

  /// 处理更新分类顺序事件
  FutureOr<void> _onUpdateCategoryOrder(
      UpdateCategoryOrder event, Emitter<CategoryState> emit) {
    // 更新原始数据中的分类顺序
    for (var newCategory in event.categories) {
      final index = _categories.indexWhere((cat) => cat.id == newCategory.id);
      if (index != -1) {
        // 更新分类数据
        _categories[index] = newCategory;
      }
    }

    // 重新排序原始数据，确保顺序正确
    final newOrder = event.categories.map((cat) => cat.id).toList();
    _categories.sort(
        (a, b) => newOrder.indexOf(a.id).compareTo(newOrder.indexOf(b.id)));

    // 使用保存的类型过滤分类列表
    List<Category> updatedCategories = _categories;
    if (_currentType != null) {
      updatedCategories =
          _categories.where((cat) => cat.type == _currentType).toList();
    }
    emit(CategoryLoaded(updatedCategories));

    // 保存到存储
    _saveCategoriesToStorage();
  }
}
