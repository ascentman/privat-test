import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/result.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/usecases/search_movies.dart';

part 'movie_search_bloc.freezed.dart';
part 'movie_search_event.dart';
part 'movie_search_state.dart';

/// Drives the search screen.
@injectable
class MovieSearchBloc extends Bloc<MovieSearchEvent, MovieSearchState> {
  MovieSearchBloc(this._searchMovies)
    : super(const MovieSearchState.initial()) {
    on<QueryChanged>(_onQueryChanged, transformer: _debounceRestartable());
    on<Retried>(_onRetried, transformer: restartable());
    on<Cleared>(_onCleared, transformer: restartable());
  }

  /// Long enough to swallow intermediate keystrokes, short enough to feel live.
  static const Duration debounceDuration = Duration(milliseconds: 300);

  final SearchMovies _searchMovies;

  String _lastQuery = '';

  /// Identifies the search the user is currently waiting for.
  ///
  /// `restartable()` only cancels within a single `on<Event>` pipeline, so a
  /// slow [QueryChanged] can still resolve after a [Cleared] or a newer
  /// [Retried] and overwrite the screen with results for a query the user has
  /// already moved on from. Comparing this token before emitting drops those.
  int _requestId = 0;

  Future<void> _onQueryChanged(
    QueryChanged event,
    Emitter<MovieSearchState> emit,
  ) async {
    _lastQuery = event.query;
    await _search(event.query, emit);
  }

  Future<void> _onRetried(Retried event, Emitter<MovieSearchState> emit) =>
      _search(_lastQuery, emit);

  void _onCleared(Cleared event, Emitter<MovieSearchState> emit) {
    _lastQuery = '';
    // Invalidates anything still in flight, so a late response cannot undo the
    // clear the user just asked for.
    _requestId++;
    emit(const MovieSearchState.initial());
  }

  Future<void> _search(String query, Emitter<MovieSearchState> emit) async {
    final requestId = ++_requestId;
    final trimmed = query.trim();
    if (trimmed.length < SearchMovies.minQueryLength) {
      // Too short is not an error the user needs shouted at them — the screen
      // simply goes back to its "type something" prompt.
      emit(const MovieSearchState.initial());
      return;
    }

    emit(const MovieSearchState.loading());
    final result = await _searchMovies(trimmed);
    if (requestId != _requestId) {
      // Superseded while in flight — the screen has moved on.
      return;
    }
    switch (result) {
      case Ok(:final value):
        emit(
          value.movies.isEmpty
              ? MovieSearchState.empty(trimmed, fromCache: value.fromCache)
              : MovieSearchState.loaded(
                  movies: value.movies,
                  fromCache: value.fromCache,
                ),
        );
      case Err(:final failure):
        emit(MovieSearchState.failure(failure));
    }
  }

  /// Debounce the keystrokes, then let a newer query cancel the in-flight one.
  static EventTransformer<T> _debounceRestartable<T>() =>
      (events, mapper) => restartable<T>()(events.debounce(debounceDuration), mapper);
}
