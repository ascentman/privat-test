import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

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
    // One pipeline for the events that replace what is on screen, not one per
    // type: `restartable()` only cancels within the pipeline it is applied to,
    // so separate handlers left a clear unable to call off a query — whether
    // that query was already awaiting the network or still sitting in the
    // debounce window.
    on<MovieSearchEvent>(
      _onEvent,
      transformer: restartable(),
      // Paging is not one of them: it appends to the current screen, and
      // scrolling fires it repeatedly. `droppable()` ignores the repeats
      // while one page is in flight instead of cancelling and restarting.
      // A late page is guarded against a changed query in the handler.
    );
    on<LoadMoreRequested>(_onLoadMore, transformer: droppable());
  }

  /// Long enough to swallow intermediate keystrokes, short enough to feel live.
  static const Duration debounceDuration = Duration(milliseconds: 300);

  final SearchMovies _searchMovies;

  String _lastQuery = '';

  Future<void> _onEvent(
    MovieSearchEvent event,
    Emitter<MovieSearchState> emit,
  ) async {
    switch (event) {
      // Handled on its own pipeline; see the constructor.
      case LoadMoreRequested():
        return;
      case QueryChanged(:final query):
        // Debounced here rather than in the transformer so that the wait is
        // part of the handler, and any newer event cancels it along with the
        // search it was about to start.
        await Future<void>.delayed(debounceDuration);
        if (emit.isDone) {
          return;
        }
        _lastQuery = query;
        await _search(query, emit);
      case Retried():
        await _search(_lastQuery, emit);
      case Cleared():
        _lastQuery = '';
        emit(const MovieSearchState.initial());
    }
  }

  Future<void> _search(String query, Emitter<MovieSearchState> emit) async {
    final trimmed = query.trim();
    if (trimmed.length < SearchMovies.minQueryLength) {
      // Too short is not an error the user needs shouted at them — the screen
      // simply goes back to its "type something" prompt.
      emit(const MovieSearchState.initial());
      return;
    }

    emit(const MovieSearchState.loading());
    final result = await _searchMovies((query: trimmed, page: 1));
    if (emit.isDone) {
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
                  query: trimmed,
                  fromCache: value.fromCache,
                  totalResults: value.totalResults,
                  page: value.page,
                  hasMore: value.hasMore,
                ),
        );
      case Err(:final failure):
        emit(MovieSearchState.failure(failure));
    }
  }

  Future<void> _onLoadMore(
    LoadMoreRequested event,
    Emitter<MovieSearchState> emit,
  ) async {
    final current = state;
    if (current is! SearchLoaded || !current.hasMore || current.isLoadingMore) {
      return;
    }
    final query = current.query;
    emit(current.copyWith(isLoadingMore: true));

    final result = await _searchMovies((query: query, page: current.page + 1));

    final latest = state;
    // The screen may have moved to another query, or been cleared, while this
    // page was in flight. Appending it then would be worse than losing it.
    if (emit.isDone || latest is! SearchLoaded || latest.query != query) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        emit(
          latest.copyWith(
            movies: [...latest.movies, ...value.movies],
            totalResults: value.totalResults,
            page: value.page,
            hasMore: value.hasMore,
            isLoadingMore: false,
          ),
        );
      case Err():
        // Keep what is on screen; the user can scroll again to retry.
        emit(latest.copyWith(isLoadingMore: false));
    }
  }
}
