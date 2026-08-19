part of 'movie_search_bloc.dart';

@freezed
sealed class MovieSearchState with _$MovieSearchState {
  /// Nothing searched yet, or the query is below the minimum length.
  const factory MovieSearchState.initial() = SearchInitial;

  const factory MovieSearchState.loading() = SearchLoading;

  /// [fromCache] is true when the network failed and sqflite answered instead.
  const factory MovieSearchState.loaded({
    required List<Movie> movies,
    @Default(false) bool fromCache,
  }) = SearchLoaded;

  /// The search succeeded but matched nothing.
  const factory MovieSearchState.empty(String query) = SearchEmpty;

  const factory MovieSearchState.failure(Failure failure) = SearchFailure;
}
