import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moment_keep/domain/entities/habit.dart';
import 'package:moment_keep/domain/entities/todo.dart';
import 'package:moment_keep/domain/entities/diary.dart';
import 'package:moment_keep/domain/entities/star_exchange.dart';
import 'package:moment_keep/presentation/blocs/habit_bloc.dart';
import 'package:moment_keep/presentation/blocs/todo_bloc.dart';
import 'package:moment_keep/presentation/blocs/diary_bloc.dart';
import 'package:moment_keep/services/product_database_service.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object> get props => [];
}

class SearchAll extends SearchEvent {
  final String query;

  const SearchAll(this.query);

  @override
  List<Object> get props => [query];
}

class SearchByModule extends SearchEvent {
  final String query;
  final String module;

  const SearchByModule(this.query, this.module);

  @override
  List<Object> get props => [query, module];
}

class ClearSearch extends SearchEvent {}

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {
  final String query;

  const SearchLoading(this.query);

  @override
  List<Object> get props => [query];
}

class SearchLoaded extends SearchState {
  final Map<String, List<dynamic>> results;
  final String query;

  const SearchLoaded({required this.results, required this.query});

  @override
  List<Object> get props => [results, query];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final HabitBloc _habitBloc;
  final TodoBloc _todoBloc;
  final DiaryBloc _diaryBloc;
  final ProductDatabaseService _productDatabaseService = ProductDatabaseService();

  SearchBloc(this._habitBloc, this._todoBloc, this._diaryBloc)
      : super(SearchInitial()) {
    on<SearchAll>(_onSearchAll, transformer: _debounce(const Duration(milliseconds: 300)));
    on<SearchByModule>(_onSearchByModule, transformer: _debounce(const Duration(milliseconds: 300)));
    on<ClearSearch>(_onClearSearch);
  }

  EventTransformer<T> _debounce<T>(Duration duration) {
    return (events, mapper) {
      Timer? timer;
      StreamController<T>? controller;
      StreamSubscription<T>? sub; // ignore: unused_local_variable

      controller = StreamController<T>(
        onListen: () {
          sub = events.listen(
            (event) {
              timer?.cancel();
              timer = Timer(duration, () {
                controller?.add(event);
              });
            },
            onError: controller?.addError,
            onDone: () {
              timer?.cancel();
              controller?.close();
            },
          );
        },
      );

      return controller.stream.asyncExpand(mapper);
    };
  }

  FutureOr<void> _onSearchAll(
      SearchAll event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading(query));

    final results = <String, List<dynamic>>{};

    results['habits'] = _searchHabits(query);
    results['todos'] = _searchTodos(query);
    results['diaries'] = _searchDiaries(query);
    results['products'] = await _searchProducts(query);

    emit(SearchLoaded(results: results, query: query));
  }

  FutureOr<void> _onSearchByModule(
      SearchByModule event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading(query));

    final results = <String, List<dynamic>>{};

    switch (event.module) {
      case 'habits':
        results['habits'] = _searchHabits(query);
        break;
      case 'todos':
        results['todos'] = _searchTodos(query);
        break;
      case 'diaries':
        results['diaries'] = _searchDiaries(query);
        break;
      case 'products':
        results['products'] = await _searchProducts(query);
        break;
    }

    emit(SearchLoaded(results: results, query: query));
  }

  FutureOr<void> _onClearSearch(
      ClearSearch event, Emitter<SearchState> emit) {
    emit(SearchInitial());
  }

  List<Habit> _searchHabits(String query) {
    final lowerQuery = query.toLowerCase();
    final habitState = _habitBloc.state;
    List<Habit> allHabits;
    if (habitState is HabitLoaded) {
      allHabits = habitState.habits;
    } else if (habitState is HabitSearchResult) {
      allHabits = habitState.filteredHabits;
    } else {
      return [];
    }

    return allHabits.where((habit) {
      return habit.name.toLowerCase().contains(lowerQuery) ||
          habit.notes.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<Todo> _searchTodos(String query) {
    final lowerQuery = query.toLowerCase();
    final todoState = _todoBloc.state;
    if (todoState is! TodoLoaded) return [];

    return todoState.todos.where((todo) {
      final titleMatch = todo.title.toLowerCase().contains(lowerQuery);
      final contentMatch = todo.content.any((block) =>
          block.type == ContentBlockType.text &&
          block.data.toLowerCase().contains(lowerQuery));
      return titleMatch || contentMatch;
    }).toList();
  }

  List<Journal> _searchDiaries(String query) {
    final lowerQuery = query.toLowerCase();
    final diaryState = _diaryBloc.state;
    if (diaryState is! DiaryLoaded) return [];

    return diaryState.entries.where((entry) {
      final titleMatch = entry.title.toLowerCase().contains(lowerQuery);
      final contentMatch = entry.content.any((block) =>
          block.type == ContentBlockType.text &&
          block.data.toLowerCase().contains(lowerQuery));
      final tagMatch = entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      return titleMatch || contentMatch || tagMatch;
    }).toList();
  }

  Future<List<StarProduct>> _searchProducts(String query) async {
    final lowerQuery = query.toLowerCase();
    try {
      final productsData = await _productDatabaseService.getAllProducts();
      final products = productsData
          .map<StarProduct>((map) => StarProduct.fromMap(map))
          .toList();

      return products.where((product) {
        return product.name.toLowerCase().contains(lowerQuery) ||
            (product.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
